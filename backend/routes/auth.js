const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const User = require('../models/User');
const {
  issueAuthTokens,
  findUserByRefreshToken,
  rotateRefreshToken,
  revokeRefreshToken,
  signAccessToken,
} = require('../utils/tokens');

function sendAuthResponse(res, authPayload) {
  res.json(authPayload);
}

// Register
router.post('/register', async (req, res) => {
  const { username, email, password } = req.body;
  if (!username || !email || !password) {
    return res.status(400).json({ message: 'All fields required' });
  }
  try {
    const existing = await User.findOne({ $or: [{ username }, { email }] });
    if (existing) return res.status(409).json({ message: 'User already exists' });
    const passwordHash = await bcrypt.hash(password, 10);
    const user = await User.create({ username, email, passwordHash });
    const authPayload = await issueAuthTokens(user);
    sendAuthResponse(res, authPayload);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// Login
router.post('/login', async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) return res.status(400).json({ message: 'All fields required' });
  try {
    const user = await User.findOne({ username });
    if (!user) return res.status(401).json({ message: 'Invalid credentials' });
    const match = await bcrypt.compare(password, user.passwordHash);
    if (!match) return res.status(401).json({ message: 'Invalid credentials' });
    const authPayload = await issueAuthTokens(user);
    sendAuthResponse(res, authPayload);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// Refresh access token using a long-lived refresh token
router.post('/refresh', async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    return res.status(400).json({ message: 'Refresh token required' });
  }

  try {
    const match = await findUserByRefreshToken(refreshToken);
    if (!match) {
      return res.status(401).json({ message: 'Invalid or expired refresh token' });
    }

    const user = match.user;
    const userId = user._id.toString();
    const accessToken = signAccessToken({ id: userId, username: user.username });
    const newRefreshToken = await rotateRefreshToken(userId, refreshToken);

    if (!newRefreshToken) {
      return res.status(401).json({ message: 'Invalid or expired refresh token' });
    }

    res.json({
      accessToken,
      refreshToken: newRefreshToken,
      token: accessToken,
      user: {
        id: userId,
        username: user.username,
        email: user.email,
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// Logout current device session
router.post('/logout', async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    return res.status(400).json({ message: 'Refresh token required' });
  }

  try {
    const match = await findUserByRefreshToken(refreshToken);
    if (match) {
      await revokeRefreshToken(match.user._id, refreshToken);
    }
    res.json({ message: 'Logged out' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router;
