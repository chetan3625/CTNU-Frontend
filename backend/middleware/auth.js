const jwt = require('jsonwebtoken');
const { verifyAccessTokenString } = require('../utils/tokens');

const secret = process.env.JWT_SECRET || 'your_jwt_secret';

function signToken(payload) {
  return jwt.sign(payload, secret, { expiresIn: '7d' });
}

function verifyToken(req, res, next) {
  if (typeof req === 'string') {
    return verifyAccessTokenString(req);
  }

  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ message: 'Access token missing or invalid' });
  }

  jwt.verify(token, secret, (err, decoded) => {
    if (err) {
      return res.status(401).json({ message: 'Invalid or expired access token' });
    }
    req.user = decoded;
    next();
  });
}

module.exports = { signToken, verifyToken };
