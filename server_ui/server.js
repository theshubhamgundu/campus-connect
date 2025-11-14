const express = require('express');
const WebSocket = require('ws');
const http = require('http');
const path = require('path');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server, path: '/ws' });

// Serve static files
app.use(express.static(path.join(__dirname, 'web')));

// WebSocket server state
const clients = new Map();
let totalConnections = 0;
let totalMessages = 0;

// WebSocket connection handling
wss.on('connection', (ws, req) => {
    const clientId = Date.now().toString();
    const clientInfo = {
        id: clientId,
        address: req.socket.remoteAddress,
        connectedAt: new Date(),
        userId: null,
        displayName: null
    };
    
    clients.set(ws, clientInfo);
    totalConnections++;
    
    console.log(`Client connected: ${clientInfo.address} (${clientId})`);
    
    ws.on('message', (data) => {
        try {
            const message = JSON.parse(data.toString());
            totalMessages++;
            handleMessage(ws, message);
        } catch (error) {
            console.error('Error parsing message:', error);
            sendError(ws, 'Invalid JSON message');
        }
    });
    
    ws.on('close', () => {
        const client = clients.get(ws);
        if (client) {
            console.log(`Client disconnected: ${client.address} (${client.id})`);
            clients.delete(ws);
        }
    });
    
    ws.on('error', (error) => {
        console.error('WebSocket error:', error);
        clients.delete(ws);
    });
});

function handleMessage(ws, message) {
    const client = clients.get(ws);
    if (!client) return;
    
    switch (message.type) {
        case 'login':
            handleLogin(ws, message);
            break;
        case 'message':
            handleMessageForward(ws, message);
            break;
        case 'announcement':
            handleAnnouncement(ws, message);
            break;
        case 'who':
            handleWho(ws);
            break;
        case 'fileMeta':
            handleFileMeta(ws, message);
            break;
        case 'fileChunk':
            handleFileChunk(ws, message);
            break;
        default:
            sendError(ws, `Unknown message type: ${message.type}`);
    }
}

function handleLogin(ws, message) {
    const client = clients.get(ws);
    if (!client) return;
    
    const userId = message.userId?.toString().trim();
    const displayName = message.displayName?.toString().trim() || userId;
    
    if (!userId) {
        send(ws, { type: 'loginAck', ok: false, reason: 'missing_userId' });
        return;
    }
    
    client.userId = userId;
    client.displayName = displayName;
    
    send(ws, {
        type: 'loginAck',
        ok: true,
        userId: userId,
        displayName: displayName
    });
    
    // Notify other clients
    broadcast({
        type: 'presence',
        event: 'online',
        userId: userId,
        displayName: displayName
    }, ws);
    
    console.log(`User logged in: ${userId} (${displayName})`);
}

function handleMessageForward(ws, message) {
    const client = clients.get(ws);
    if (!client || !client.userId) {
        sendError(ws, 'Not logged in');
        return;
    }
    
    const to = message.to?.toString();
    const text = message.text?.toString();
    
    if (!to || !text) {
        sendError(ws, 'Invalid message');
        return;
    }
    
    const payload = {
        type: 'message',
        from: client.userId,
        to: to,
        text: text,
        ts: new Date().toISOString()
    };
    
    if (to.startsWith('room:')) {
        // Room message - broadcast to all clients
        broadcast(payload);
    } else {
        // Direct message - find target client
        const targetWs = findClientByUserId(to);
        if (targetWs) {
            send(targetWs, payload);
        }
        // Echo back to sender
        send(ws, payload);
    }
    
    console.log(`Message from ${client.userId} to ${to}: ${text}`);
}

function handleAnnouncement(ws, message) {
    const client = clients.get(ws);
    if (!client || !client.userId) {
        sendError(ws, 'Not logged in');
        return;
    }
    
    const text = message.text?.toString();
    if (!text) {
        sendError(ws, 'Invalid announcement');
        return;
    }
    
    broadcast({
        type: 'announcement',
        from: client.userId,
        text: text,
        ts: new Date().toISOString()
    });
    
    console.log(`Announcement from ${client.userId}: ${text}`);
}

function handleWho(ws) {
    const client = clients.get(ws);
    if (!client || !client.userId) {
        sendError(ws, 'Not logged in');
        return;
    }
    
    const onlineUsers = Array.from(clients.values())
        .filter(c => c.userId)
        .map(c => ({
            userId: c.userId,
            displayName: c.displayName
        }));
    
    send(ws, {
        type: 'who',
        users: onlineUsers
    });
}

function handleFileMeta(ws, message) {
    const client = clients.get(ws);
    if (!client || !client.userId) {
        sendError(ws, 'Not logged in');
        return;
    }
    
    const to = message.to?.toString();
    const fileId = message.fileId?.toString();
    
    if (!fileId) {
        sendError(ws, 'Invalid file metadata');
        return;
    }
    
    const payload = {
        type: 'fileMeta',
        from: client.userId,
        to: to,
        fileId: fileId,
        name: message.name,
        size: message.size,
        mime: message.mime,
        ts: new Date().toISOString()
    };
    
    if (to) {
        if (to.startsWith('room:')) {
            broadcast(payload);
        } else {
            const targetWs = findClientByUserId(to);
            if (targetWs) {
                send(targetWs, payload);
            }
        }
        send(ws, payload);
    } else {
        broadcast(payload);
    }
}

function handleFileChunk(ws, message) {
    const client = clients.get(ws);
    if (!client || !client.userId) {
        sendError(ws, 'Not logged in');
        return;
    }
    
    const to = message.to?.toString();
    const payload = {
        type: 'fileChunk',
        from: client.userId,
        to: to,
        fileId: message.fileId,
        seq: message.seq,
        eof: message.eof || false,
        dataBase64: message.dataBase64,
        ts: new Date().toISOString()
    };
    
    if (to) {
        if (to.startsWith('room:')) {
            broadcast(payload);
        } else {
            const targetWs = findClientByUserId(to);
            if (targetWs) {
                send(targetWs, payload);
            }
        }
        send(ws, payload);
    } else {
        broadcast(payload);
    }
}

function send(ws, message) {
    if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify(message));
    }
}

function broadcast(message, excludeWs = null) {
    clients.forEach((client, ws) => {
        if (ws !== excludeWs && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify(message));
        }
    });
}

function sendError(ws, error) {
    send(ws, {
        type: 'error',
        error: error
    });
}

function findClientByUserId(userId) {
    for (const [ws, client] of clients) {
        if (client.userId === userId) {
            return ws;
        }
    }
    return null;
}

// Start server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`CampusNet Server UI running on http://localhost:${PORT}`);
    console.log(`WebSocket server running on ws://localhost:${PORT}/ws`);
    console.log(`Total connections: ${totalConnections}`);
    console.log(`Total messages: ${totalMessages}`);
    console.log(`Connected clients: ${clients.size}`);
});

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('\nShutting down server...');
    server.close(() => {
        console.log('Server closed');
        process.exit(0);
    });
});
