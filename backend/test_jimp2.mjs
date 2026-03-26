import { Jimp } from 'jimp';

// Test with a tiny 1x1 white JPEG (smallest valid JPEG)
const whiteJpegB64 = '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAARC'
  + 'AABAAEDASIA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/xAAUAQEAAAAAAAAAAAAAAAAAAAAA/8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/a'
  + 'AAwDAQACEQMRAD8AKwAB/9k=';

const buf = Buffer.from(whiteJpegB64, 'base64');
console.log('buf length', buf.length);

try {
  const img = await Jimp.fromBuffer(buf);
  console.log('fromBuffer works, bitmap:', img.bitmap.width, img.bitmap.height);
} catch(e) {
  console.log('fromBuffer failed:', e.message);
}

try {
  const img2 = await Jimp.read(buf);
  console.log('read works');
} catch(e) {
  console.log('read failed:', e.message);
}
