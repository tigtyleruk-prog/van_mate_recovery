import { copyFile, mkdir } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const rootDir = process.cwd();
const sourceDir = path.join(rootDir, 'web');
const targetDir = path.join(rootDir, 'build', 'web');
const files = [
  'booking_link.html',
  'pin_request.html',
  'quote_response.html',
  'request.html',
];

await mkdir(targetDir, { recursive: true });

for (const fileName of files) {
  const sourcePath = path.join(sourceDir, fileName);
  const targetPath = path.join(targetDir, fileName);
  await copyFile(sourcePath, targetPath);
  console.log(`Copied ${fileName} -> build/web/${fileName}`);
}
