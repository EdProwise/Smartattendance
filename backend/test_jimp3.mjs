import { Jimp } from 'jimp';
import mongoose from 'mongoose';

const MONGO_URI = 'mongodb+srv://edprowise_db_user:PTx7QbEglhESE9Ie@cluster0.wcjw48r.mongodb.net/Smartattendance';
await mongoose.connect(MONGO_URI);

const Employee = mongoose.model('Employee', new mongoose.Schema({ photoBase64: String }));
const emp = await Employee.findOne({ photoBase64: { $ne: null } }).lean();
if (!emp || !emp.photoBase64) { console.log('No enrolled employees'); process.exit(1); }

console.log('Photo b64 length:', emp.photoBase64.length);
const buf = Buffer.from(emp.photoBase64, 'base64');
console.log('Buffer bytes:', buf.length, '  first 4 bytes:', buf[0], buf[1], buf[2], buf[3]);

try {
  const img = await Jimp.fromBuffer(buf);
  console.log('fromBuffer OK:', img.bitmap.width, 'x', img.bitmap.height);
  img.resize({ w: 64, h: 64 });
  img.greyscale();
  const pixels = [];
  for (let i = 0; i < img.bitmap.data.length; i += 4) pixels.push(img.bitmap.data[i]);
  console.log('pixels length:', pixels.length, 'sample[0]:', pixels[0]);
} catch(e) {
  console.log('fromBuffer failed:', e.message);
}

await mongoose.disconnect();
