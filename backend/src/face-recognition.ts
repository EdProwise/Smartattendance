/**
 * Face recognition using @vladmandic/face-api (TensorFlow.js neural network).
 * Uses the WASM-based Node.js build to avoid native @tensorflow/tfjs-node bindings.
 * Models are loaded from the package's own model directory (no download needed).
 *
 * Enrollment  → extract a 128-D face descriptor and store it in MongoDB.
 * Scan        → extract descriptor from the scan photo, compare to stored
 *               descriptors via Euclidean distance.  Distance < 0.5 ≈ same person.
 */

import type * as FaceAPITypes from '@vladmandic/face-api';
import { createCanvas, loadImage } from 'canvas';
import path from 'path';

// ─── Paths ───────────────────────────────────────────────────────────────────

// Use the model files bundled with the package — no network download required
const MODELS_DIR = path.join(
  process.cwd(),
  'node_modules',
  '@vladmandic',
  'face-api',
  'model'
);

// ─── Match threshold ──────────────────────────────────────────────────────────
// Euclidean distance between two 128-D descriptors.
// < 0.5  →  very likely same person
// 0.5–0.6 →  probable match
// > 0.6  →  different person
export const DESCRIPTOR_THRESHOLD = 0.5;

// ─── Initialisation (lazy, runs once) ────────────────────────────────────────

let ready = false;
// Loaded lazily in initFaceApi — typed as any so we can assign the CJS module
// eslint-disable-next-line @typescript-eslint/no-explicit-any
let faceapi: any;

export async function initFaceApi(): Promise<void> {
  if (ready) return;

  // Load the WASM-based variant — no native @tensorflow/tfjs-node required.
  // Using a variable prevents TypeScript from trying to statically resolve the
  // non-standard package sub-path.
  const wasmEntry = '@vladmandic/face-api/dist/face-api.node-wasm.js';
  const mod = await import(wasmEntry as string);
  faceapi = mod.default ?? mod;

  // Wait for the WASM backend to finish async initialization.
  // Import tf directly since the re-export from face-api may not expose it.
  const tfEntry = '@tensorflow/tfjs';
  const tf = await import(tfEntry as string);
  await tf.ready();

  // Patch face-api with the node-canvas implementations so it can run in Node.js
  const { Canvas, Image, ImageData } = await import('canvas');
  faceapi.env.monkeyPatch({ Canvas, Image, ImageData });

  await faceapi.nets.tinyFaceDetector.loadFromDisk(MODELS_DIR);
  await faceapi.nets.faceLandmark68TinyNet.loadFromDisk(MODELS_DIR);
  await faceapi.nets.faceRecognitionNet.loadFromDisk(MODELS_DIR);

  ready = true;
  console.log('[FaceAPI] Models loaded – face recognition ready');
}

// ─── Core helpers ─────────────────────────────────────────────────────────────

function stripPrefix(base64: string): string {
  const i = base64.indexOf(',');
  return i !== -1 ? base64.substring(i + 1) : base64;
}

/**
 * Extract a 128-D face descriptor from a base64-encoded image.
 * Returns null when no face is detected.
 */
export async function extractDescriptor(base64: string): Promise<number[] | null> {
  await initFaceApi();

  const buf = Buffer.from(stripPrefix(base64), 'base64');
  const img = await loadImage(buf);

  const canvas = createCanvas(img.width as number, img.height as number);
  const ctx    = canvas.getContext('2d');
  ctx.drawImage(img as any, 0, 0);

  const opts = new faceapi.TinyFaceDetectorOptions({
    inputSize: 416,
    scoreThreshold: 0.3,
  });

  const detection = await faceapi
    .detectSingleFace(canvas as any, opts)
    .withFaceLandmarks(true)
    .withFaceDescriptor();

  if (!detection) return null;
  return Array.from(detection.descriptor);
}

/**
 * Euclidean distance between two 128-D descriptors.
 * Lower = more similar. Threshold ≈ 0.5 for a confident match.
 */
export function descriptorDistance(a: number[], b: number[]): number {
  let sum = 0;
  for (let i = 0; i < Math.min(a.length, b.length); i++) {
    sum += (a[i] - b[i]) ** 2;
  }
  return Math.sqrt(sum);
}
