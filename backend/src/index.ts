import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { bodyLimit } from 'hono/body-limit';
import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import { Employee } from './models/Employee.js';
import { AttendanceRecord } from './models/AttendanceRecord.js';
import { User } from './models/User.js';
import {
  extractDescriptor,
  descriptorDistance,
  DESCRIPTOR_THRESHOLD,
  initFaceApi,
} from './face-recognition.js';

// ─── MongoDB Connection ───────────────────────────────────────────────────────

const MONGO_URI =
  process.env.MONGO_URI ||
  'mongodb://edprowise_db_user:PTx7QbEglhESE9Ie@ac-hrlyz9q-shard-00-00.wcjw48r.mongodb.net:27017,ac-hrlyz9q-shard-00-01.wcjw48r.mongodb.net:27017,ac-hrlyz9q-shard-00-02.wcjw48r.mongodb.net:27017/Smartattendance?ssl=true&replicaSet=atlas-zshpxx-shard-0&authSource=admin&retryWrites=true&w=majority';

async function seedDefaultAdmin() {
  try {
    const existing = await User.findOne({ loginId: 'admin' });
    if (!existing) {
      const passwordHash = await bcrypt.hash('Admin@123', 12);
      await User.create({
        loginId: 'admin',
        email: 'admin@edprowise.com',
        passwordHash,
        role: 'admin',
      });
      console.log('[Seed] Default admin created → loginId: admin  password: Admin@123');
    } else if (existing.role !== 'admin') {
      await User.findByIdAndUpdate(existing._id, { role: 'admin' });
      console.log('[Seed] Existing "admin" user promoted to role: admin');
    }
  } catch (err) {
    console.error('[Seed] Failed to seed admin:', err);
  }
}

mongoose
  .connect(MONGO_URI)
  .then(async () => {
    console.log('[MongoDB] Connected to Smartattendance');
    await seedDefaultAdmin();
    // Warm up face-recognition models in the background (don't block startup)
    initFaceApi().catch((err) => console.error('[FaceAPI] Init error:', err));
  })
  .catch((err) => console.error('[MongoDB] Connection error:', err));

// ─── App ─────────────────────────────────────────────────────────────────────

const app = new Hono();

app.use(
  '*',
  cors({
    credentials: true,
    origin: (origin) => origin || '*',
  })
);

// Allow up to 10 MB for photo uploads (enroll + scan send base64 images)
app.use(
  '*',
  bodyLimit({
    maxSize: 10 * 1024 * 1024, // 10 MB
    onError: (c) => c.json({ error: 'Payload too large (max 10 MB)' }, 413),
  })
);

// ─── Root ─────────────────────────────────────────────────────────────────────

app.get('/', (c) => c.json({ message: 'Smart Attendance System API', version: '1.0' }));

// ─── Employees ────────────────────────────────────────────────────────────────

function serializeEmployee(e: any, includePhoto = false) {
  return {
    id: e._id.toString(),
    employeeId: e.employeeId ?? '',
    name: e.name,
    designation: e.designation ?? '',
    grade: e.grade ?? '',
    category: e.category ?? '',
    gender: e.gender ?? '',
    mobile: e.mobile ?? '',
    photoBase64: includePhoto ? (e.photoBase64 ?? null) : (e.photoBase64 ? '[photo stored]' : null),
    // Employee is enrolled when they have a face descriptor (128-D vector)
    isEnrolled: Array.isArray(e.faceDescriptor) && e.faceDescriptor.length === 128,
    createdAt: e.createdAt,
  };
}

app.get('/employees', async (c) => {
  const employees = await Employee.find().sort({ createdAt: -1 }).lean();
  return c.json(employees.map((e) => serializeEmployee(e)));
});

app.get('/employees/:id', async (c) => {
  const emp = await Employee.findById(c.req.param('id')).lean();
  if (!emp) return c.json({ error: 'Employee not found' }, 404);
  return c.json(serializeEmployee(emp, true));
});

app.post('/employees', async (c) => {
  const body = await c.req.json<{
    employeeId: string; name: string; designation?: string; grade?: string;
    category?: string; gender?: string; mobile?: string;
  }>();
  if (!body.employeeId || !body.name) {
    return c.json({ error: 'employeeId and name are required' }, 400);
  }
  try {
    const emp = await Employee.create({
      employeeId: body.employeeId,
      name: body.name,
      designation: body.designation ?? '',
      grade: body.grade ?? '',
      category: body.category ?? '',
      gender: body.gender ?? '',
      mobile: body.mobile ?? '',
    });
    return c.json(serializeEmployee(emp.toObject()), 201);
  } catch (err: any) {
    if (err.code === 11000) {
      return c.json({ error: 'Employee ID already exists' }, 409);
    }
    return c.json({ error: 'Failed to create employee' }, 500);
  }
});

// Bulk import — array of employee objects
app.post('/employees/bulk', async (c) => {
  const body = await c.req.json<{ employees: any[] }>();
  if (!Array.isArray(body.employees) || body.employees.length === 0) {
    return c.json({ error: 'employees array is required' }, 400);
  }
  const results: { success: boolean; employeeId: string; error?: string }[] = [];
  for (const row of body.employees) {
    if (!row.employeeId || !row.name) {
      results.push({ success: false, employeeId: row.employeeId ?? '?', error: 'Missing required fields' });
      continue;
    }
    try {
      await Employee.create({
        employeeId: String(row.employeeId).trim(),
        name: String(row.name).trim(),
        designation: String(row.designation ?? '').trim(),
        grade: String(row.grade ?? '').trim(),
        category: String(row.category ?? '').trim(),
        gender: String(row.gender ?? '').trim(),
        mobile: String(row.mobile ?? row.email ?? '').trim(),
      });
      results.push({ success: true, employeeId: String(row.employeeId) });
    } catch (err: any) {
      const msg = err.code === 11000 ? 'Employee ID duplicate' : 'Failed to save';
      results.push({ success: false, employeeId: String(row.employeeId), error: msg });
    }
  }
  const succeeded = results.filter((r) => r.success).length;
  return c.json({ imported: succeeded, total: results.length, results }, 200);
});

app.put('/employees/:id', async (c) => {
  const body = await c.req.json<{
    employeeId?: string; name?: string; designation?: string; grade?: string;
    category?: string; gender?: string; mobile?: string;
  }>();
  const emp = await Employee.findByIdAndUpdate(c.req.param('id'), body, { returnDocument: 'after' }).lean();
  if (!emp) return c.json({ error: 'Employee not found' }, 404);
  return c.json(serializeEmployee(emp));
});

app.delete('/employees/:id', async (c) => {
  const emp = await Employee.findByIdAndDelete(c.req.param('id'));
  if (!emp) return c.json({ error: 'Employee not found' }, 404);
  return c.json({ success: true });
});

// ─── Face Enrollment ──────────────────────────────────────────────────────────

app.post('/employees/:id/enroll', async (c) => {
  const body = await c.req.json<{ photoBase64: string }>();
  if (!body.photoBase64) return c.json({ error: 'photoBase64 is required' }, 400);

  // Extract 128-D face descriptor using neural network
  let descriptor: number[] | null;
  try {
    descriptor = await extractDescriptor(body.photoBase64);
  } catch (err) {
    console.error('[enroll] Face extraction error:', err);
    return c.json({ error: 'Failed to process image. Please try again with a clearer photo.' }, 500);
  }

  if (!descriptor) {
    return c.json({
      error: 'No face detected in the photo. Please use a clear, well-lit photo where your face is visible.',
    }, 422);
  }

  const emp = await Employee.findByIdAndUpdate(
    c.req.param('id'),
    { photoBase64: body.photoBase64, faceDescriptor: descriptor },
    { returnDocument: 'after' }
  );
  if (!emp) return c.json({ error: 'Employee not found' }, 404);

  return c.json({ success: true, message: 'Face enrolled successfully' });
});

// ─── Attendance Scan ──────────────────────────────────────────────────────────

app.post('/attendance/scan', async (c) => {
  const body = await c.req.json<{ photoBase64: string }>();
  if (!body.photoBase64) return c.json({ error: 'photoBase64 is required' }, 400);

  // Only compare against employees who have a face descriptor (properly enrolled)
  const enrolledEmployees = await Employee.find({
    faceDescriptor: { $exists: true, $ne: null, $not: { $size: 0 } },
  }).lean();

  if (enrolledEmployees.length === 0) {
    return c.json({
      matched: false,
      message: 'No employees enrolled. Please enroll employees with a face photo first.',
    });
  }

  // Extract face descriptor from the scan photo
  let scanDescriptor: number[] | null;
  try {
    scanDescriptor = await extractDescriptor(body.photoBase64);
  } catch (err) {
    console.error('[scan] Descriptor extraction error:', err);
    return c.json({ error: 'Failed to process scan image. Please try again.' }, 500);
  }

  if (!scanDescriptor) {
    return c.json({
      matched: false,
      message: 'No face detected in the scan. Please look directly at the camera and try again.',
    });
  }

  // Find the closest match using Euclidean distance on 128-D descriptors
  let bestMatch: (typeof enrolledEmployees)[0] | null = null;
  let bestDistance = Infinity;

  for (const emp of enrolledEmployees) {
    if (!Array.isArray(emp.faceDescriptor) || emp.faceDescriptor.length !== 128) continue;
    const dist = descriptorDistance(scanDescriptor, emp.faceDescriptor);
    console.log(`[scan] ${emp.name} → distance: ${dist.toFixed(4)}`);
    if (dist < bestDistance) {
      bestDistance = dist;
      if (dist <= DESCRIPTOR_THRESHOLD) bestMatch = emp;
    }
  }

  console.log(`[scan] Best distance: ${bestDistance.toFixed(4)}, matched: ${bestMatch?.name ?? 'none'}`);

  const now = new Date();

  if (bestMatch) {
    const startOfDay = new Date(now);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(now);
    endOfDay.setHours(23, 59, 59, 999);

    const alreadyMarked = await AttendanceRecord.findOne({
      employeeId: bestMatch._id.toString(),
      status: 'present',
      timestamp: { $gte: startOfDay, $lte: endOfDay },
    });

    if (alreadyMarked) {
      return c.json({
        matched: true,
        alreadyMarked: true,
        employee: { id: bestMatch._id.toString(), name: bestMatch.name },
        message: `${bestMatch.name} already marked present today.`,
      });
    }

    const record = await AttendanceRecord.create({
      employeeId: bestMatch._id.toString(),
      employeeName: bestMatch.name,
      department: bestMatch.designation ?? '',
      timestamp: now,
      status: 'present',
      photoBase64: body.photoBase64,
    });

    return c.json({
      matched: true,
      alreadyMarked: false,
      employee: { id: bestMatch._id.toString(), name: bestMatch.name },
      message: `Welcome, ${bestMatch.name}! Attendance marked.`,
      record: { id: record._id.toString(), ...record.toObject() },
    });
  } else {
    await AttendanceRecord.create({
      employeeId: 'unknown',
      employeeName: 'Unknown',
      department: '-',
      timestamp: now,
      status: 'unrecognized',
      photoBase64: body.photoBase64,
    });

    return c.json({
      matched: false,
      message: 'Face not recognized. Please contact your admin.',
    });
  }
});

// ─── Attendance Records ───────────────────────────────────────────────────────

app.get('/attendance', async (c) => {
  const date = c.req.query('date'); // YYYY-MM-DD
  let query: Record<string, any> = {};

  if (date) {
    const start = new Date(`${date}T00:00:00.000Z`);
    const end = new Date(`${date}T23:59:59.999Z`);
    query.timestamp = { $gte: start, $lte: end };
  }

  const records = await AttendanceRecord.find(query).sort({ timestamp: -1 }).lean();

  return c.json(
    records.map((r) => ({
      id: r._id.toString(),
      employeeId: r.employeeId,
      employeeName: r.employeeName,
      department: r.department,
      timestamp: r.timestamp,
      status: r.status,
      photoBase64: r.photoBase64 ? '[photo]' : null,
    }))
  );
});

app.get('/attendance/stats', async (c) => {
  const now = new Date();
  const startOfDay = new Date(now);
  startOfDay.setHours(0, 0, 0, 0);
  const endOfDay = new Date(now);
  endOfDay.setHours(23, 59, 59, 999);

  const [totalEmployees, enrolledEmployees, presentToday, unrecognizedToday, totalRecords] =
    await Promise.all([
      Employee.countDocuments(),
      Employee.countDocuments({ faceDescriptor: { $exists: true, $ne: null, $not: { $size: 0 } } }),
      AttendanceRecord.countDocuments({
        status: 'present',
        timestamp: { $gte: startOfDay, $lte: endOfDay },
      }),
      AttendanceRecord.countDocuments({
        status: 'unrecognized',
        timestamp: { $gte: startOfDay, $lte: endOfDay },
      }),
      AttendanceRecord.countDocuments(),
    ]);

  return c.json({
    totalEmployees,
    enrolledEmployees,
    presentToday,
    unrecognizedToday,
    totalRecords,
  });
});

// ─── Password policy ─────────────────────────────────────────────────────────
// Min 8 chars, 1 uppercase, 1 number, 1 symbol
const PASSWORD_REGEX = /^(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]).{8,}$/;

// ─── Auth ─────────────────────────────────────────────────────────────────────

app.post('/auth/register', async (c) => {
  const body = await c.req.json<{ loginId: string; email: string; password: string }>();
  if (!body.loginId || !body.email || !body.password) {
    return c.json({ error: 'loginId, email and password are required' }, 400);
  }
  if (!PASSWORD_REGEX.test(body.password)) {
    return c.json({
      error: 'Password must be at least 8 characters with 1 uppercase, 1 number and 1 symbol',
    }, 400);
  }
  try {
    const passwordHash = await bcrypt.hash(body.password, 12);
    const user = await User.create({ loginId: body.loginId, email: body.email, passwordHash });
    return c.json({ id: user._id.toString(), loginId: user.loginId, email: user.email, role: user.role ?? 'user' }, 201);
  } catch (err: any) {
    if (err.code === 11000) {
      const field = err.keyPattern?.loginId ? 'Login ID' : 'Email';
      return c.json({ error: `${field} already exists` }, 409);
    }
    return c.json({ error: 'Registration failed' }, 500);
  }
});

app.post('/auth/login', async (c) => {
  const body = await c.req.json<{ loginId: string; password: string }>();
  if (!body.loginId || !body.password) {
    return c.json({ error: 'loginId and password are required' }, 400);
  }
  const user = await User.findOne({ loginId: body.loginId });
  if (!user) return c.json({ error: 'Invalid login ID or password' }, 401);
  const valid = await bcrypt.compare(body.password, user.passwordHash);
  if (!valid) return c.json({ error: 'Invalid login ID or password' }, 401);
  return c.json({ id: user._id.toString(), loginId: user.loginId, email: user.email, role: user.role ?? 'user' });
});

app.post('/auth/forgot-password', async (c) => {
  const body = await c.req.json<{ email: string }>();
  if (!body.email) return c.json({ error: 'email is required' }, 400);
  const user = await User.findOne({ email: body.email.toLowerCase() });
  if (!user) {
    return c.json({ message: 'If that email is registered, a reset code has been sent.' });
  }
  const token = crypto.randomBytes(4).toString('hex').toUpperCase();
  const expiry = new Date(Date.now() + 15 * 60 * 1000);
  await User.findByIdAndUpdate(user._id, { resetToken: token, resetTokenExpiry: expiry });
  return c.json({ message: 'Reset code generated', resetCode: token });
});

app.post('/auth/reset-password', async (c) => {
  const body = await c.req.json<{ email: string; resetCode: string; newPassword: string }>();
  if (!body.email || !body.resetCode || !body.newPassword) {
    return c.json({ error: 'email, resetCode and newPassword are required' }, 400);
  }
  if (!PASSWORD_REGEX.test(body.newPassword)) {
    return c.json({
      error: 'Password must be at least 8 characters with 1 uppercase, 1 number and 1 symbol',
    }, 400);
  }
  const user = await User.findOne({ email: body.email.toLowerCase() });
  if (
    !user ||
    user.resetToken !== body.resetCode.toUpperCase() ||
    !user.resetTokenExpiry ||
    user.resetTokenExpiry < new Date()
  ) {
    return c.json({ error: 'Invalid or expired reset code' }, 400);
  }
  const passwordHash = await bcrypt.hash(body.newPassword, 12);
  await User.findByIdAndUpdate(user._id, {
    passwordHash,
    resetToken: undefined,
    resetTokenExpiry: undefined,
  });
  return c.json({ message: 'Password reset successfully' });
});

export default {
  fetch: app.fetch,
  port: 8080,
};
