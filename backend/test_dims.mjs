// 460800 bytes analysis
console.log('RGBA (4 bytes/px):', 460800/4, 'px, sqrt:', Math.sqrt(460800/4));
console.log('RGB  (3 bytes/px):', 460800/3, 'px, sqrt:', Math.sqrt(460800/3));
// 614400 b64 chars → 460800 bytes
// 460800 / 4 = 115200 pixels = 339.4 x 339.4? No
// Let's check common sizes
for (const w of [240, 320, 360, 480, 640]) {
  for (const h of [240, 320, 360, 480, 640]) {
    if (w * h * 4 === 460800) console.log(`RGBA match: ${w}x${h}`);
    if (w * h * 3 === 460800) console.log(`RGB match: ${w}x${h}`);
  }
}
