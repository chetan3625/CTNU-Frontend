const crypto = require('crypto');
const jwt = require('jsonwebtoken');

const secret = process.env.JWT_SECRET || 'your_jwt_secret';
const ACCESS_TOKEN_EXPIRY = process.env.ACCESS_TOKEN_EXPIRY || '1h';
const REFRESH_TOKEN_TTL_MS = Number(process.env.REFRESH_TOKEN_TTL_MS) || 10 * 365 * 24 * 60 * 60 * 1000;

function signAccessToken(payload) {
  return jwt.sign(payload, secret, { expiresIn: ACCESS_TOKEN_EXPIRY });
}

function verifyAccessTokenString(token) {
  return new Promise((resolve, reject) => {
    jwt.verify(token, secret, (err, decoded) => {
      if (err) return reject(err);
      resolve(decoded);
    });
  });
}

function createRefreshToken() {
  return crypto.randomBytes(64).toString('hex');
}

function hashRefreshToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function refreshTokenExpiryDate() {
  return new Date(Date.now() + REFRESH_TOKEN_TTL_MS);
}

async function storeRefreshToken(userId, refreshToken) {
  const User = require('../models/User');
  const tokenHash = hashRefreshToken(refreshToken);
  const expiresAt = refreshTokenExpiryDate();

  await User.findByIdAndUpdate(userId, {
    $push: {
      refreshTokens: {
        $each: [{ tokenHash, expiresAt, createdAt: new Date() }],
        $slice: -10,
      },
    },
  });

  return expiresAt;
}

async function revokeRefreshToken(userId, refreshToken) {
  const User = require('../models/User');
  const tokenHash = hashRefreshToken(refreshToken);
  await User.findByIdAndUpdate(userId, {
    $pull: { refreshTokens: { tokenHash } },
  });
}

async function revokeAllRefreshTokens(userId) {
  const User = require('../models/User');
  await User.findByIdAndUpdate(userId, { $set: { refreshTokens: [] } });
}

async function findUserByRefreshToken(refreshToken) {
  const User = require('../models/User');
  const tokenHash = hashRefreshToken(refreshToken);
  const user = await User.findOne({ 'refreshTokens.tokenHash': tokenHash });
  if (!user) return null;

  const stored = user.refreshTokens.find((entry) => entry.tokenHash === tokenHash);
  if (!stored) return null;
  if (stored.expiresAt && stored.expiresAt < new Date()) {
    await User.findByIdAndUpdate(user._id, {
      $pull: { refreshTokens: { tokenHash } },
    });
    return null;
  }

  return { user, tokenHash };
}

async function rotateRefreshToken(userId, oldRefreshToken) {
  const match = await findUserByRefreshToken(oldRefreshToken);
  if (!match || match.user._id.toString() !== userId.toString()) {
    return null;
  }

  const User = require('../models/User');
  await User.findByIdAndUpdate(userId, {
    $pull: { refreshTokens: { tokenHash: match.tokenHash } },
  });

  const newRefreshToken = createRefreshToken();
  await storeRefreshToken(userId, newRefreshToken);
  return newRefreshToken;
}

async function issueAuthTokens(user) {
  const userId = user._id.toString();
  const payload = { id: userId, username: user.username };
  const accessToken = signAccessToken(payload);
  const refreshToken = createRefreshToken();
  await storeRefreshToken(userId, refreshToken);

  return {
    accessToken,
    refreshToken,
    token: accessToken,
    user: {
      id: userId,
      username: user.username,
      email: user.email,
    },
  };
}

module.exports = {
  signAccessToken,
  verifyAccessTokenString,
  createRefreshToken,
  hashRefreshToken,
  refreshTokenExpiryDate,
  storeRefreshToken,
  revokeRefreshToken,
  revokeAllRefreshTokens,
  findUserByRefreshToken,
  rotateRefreshToken,
  issueAuthTokens,
};
