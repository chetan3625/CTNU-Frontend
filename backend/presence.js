// Tracks presence sockets only (notify-only background sockets are excluded).
const userConnections = new Map();

function addUserConnection(userId, socketId) {
  const id = userId.toString();
  if (!userConnections.has(id)) {
    userConnections.set(id, new Set());
  }
  const connections = userConnections.get(id);
  const wasOffline = connections.size === 0;
  connections.add(socketId);
  return wasOffline;
}

function removeUserConnection(userId, socketId) {
  const id = userId.toString();
  const connections = userConnections.get(id);
  if (!connections) return true;
  connections.delete(socketId);
  if (connections.size === 0) {
    userConnections.delete(id);
    return true;
  }
  return false;
}

function isUserConnected(userId) {
  const connections = userConnections.get(userId.toString());
  return connections != null && connections.size > 0;
}

module.exports = {
  addUserConnection,
  removeUserConnection,
  isUserConnected,
};
