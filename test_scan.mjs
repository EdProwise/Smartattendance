// Test the scan endpoint with a real enrolled employee's photo
const empRes = await fetch('http://localhost:3002/employees');
const employees = await empRes.json();
const enrolled = employees.find(e => e.photoBase64 && e.photoBase64 !== null);

if (!enrolled) {
  console.log('No enrolled employees found — enroll one first');
  process.exit(0);
}

// Fetch the full employee including photo
const fullRes = await fetch(`http://localhost:3002/employees/${enrolled.id}`);
const full = await fullRes.json();

console.log('Testing with employee:', full.name);
console.log('Photo length:', full.photoBase64?.length);

const scanRes = await fetch('http://localhost:3002/attendance/scan', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ photoBase64: full.photoBase64 }),
});
const result = await scanRes.json();
console.log('Scan result (same photo → must match):', JSON.stringify(result, null, 2));
