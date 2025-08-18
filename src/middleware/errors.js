export const notFound = (req, res, next) => {
  res.status(404).json({ success: false, error: `Not Found - ${req.originalUrl}` });
};

export const errorHandler = (err, req, res, _next) => {
  console.error('❌ Error:', err);
  const status = res.statusCode && res.statusCode !== 200 ? res.statusCode : 500;
  res.status(status).json({
    success: false,
    error: process.env.NODE_ENV === 'production' ? 'Server error' : (err.message || 'Server error'),
  });
};
