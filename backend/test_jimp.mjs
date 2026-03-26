import * as jimp from 'jimp';
console.log('keys:', Object.keys(jimp));
const { Jimp } = jimp;
console.log('Jimp methods:', Object.getOwnPropertyNames(Jimp));
