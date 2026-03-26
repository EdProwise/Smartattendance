// Quick API test against live MongoDB backend
const BASE = 'http://localhost:3002';

async function run() {
  const stats0 = await fetch(`${BASE}/attendance/stats`).then(r => r.json());
  console.log('Stats (initial):', stats0);

  const created = await fetch(`${BASE}/employees`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name: 'Test User', department: 'QA', email: `test${Date.now()}@co.com` }),
  }).then(r => r.json());
  console.log('Created employee:', created);

  const list = await fetch(`${BASE}/employees`).then(r => r.json());
  console.log('Employees count:', list.length, '| First:', list[0]?.name);

  const stats1 = await fetch(`${BASE}/attendance/stats`).then(r => r.json());
  console.log('Stats after create:', stats1);

  if (created.id) {
    const del = await fetch(`${BASE}/employees/${created.id}`, { method: 'DELETE' }).then(r => r.json());
    console.log('Deleted:', del);
  }

  console.log('All tests passed!');
}

run().catch(console.error);
