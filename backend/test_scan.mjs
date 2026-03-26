import mongoose from 'mongoose';

const MONGO_URI = 'mongodb+srv://edprowise_db_user:PTx7QbEglhESE9Ie@cluster0.wcjw48r.mongodb.net/Smartattendance';
await mongoose.connect(MONGO_URI);

const Employee = mongoose.model('Employee', new mongoose.Schema({ photoBase64: String, name: String }));
const emp = await Employee.findOne({ photoBase64: { $ne: null } }).lean();
await mongoose.disconnect();

if (!emp || !emp.photoBase64) { console.log('No enrolled employees'); process.exit(1); }
console.log('Testing with employee:', emp.name, '— photo length:', emp.photoBase64.length);

// Send the enrolled photo as the scan photo (should match itself)
const res = await fetch('http://localhost:3002/attendance/scan', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ photoBase64: emp.photoBase64 }),
});
const json = await res.json();
console.log('Status:', res.status);
console.log('Response:', JSON.stringify(json, null, 2));
