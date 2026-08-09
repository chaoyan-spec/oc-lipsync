import { access } from 'node:fs/promises';
import { constants } from 'node:fs';
import { delimiter, join } from 'node:path';

const DEFAULT_HOMEBREW_BIN = '/opt/homebrew/bin';

async function isExecutable(path) {
  try {
    await access(path, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

export async function resolveExecutable(tool, {
  homebrewBin = DEFAULT_HOMEBREW_BIN,
  pathValue = process.env.PATH || '',
} = {}) {
  const homebrewPath = join(homebrewBin, tool);
  if (await isExecutable(homebrewPath)) return homebrewPath;

  for (const directory of pathValue.split(delimiter).filter(Boolean)) {
    const candidate = join(directory, tool);
    if (await isExecutable(candidate)) return candidate;
  }

  throw new Error(
    `找不到 ${tool}。请安装到 ${join(DEFAULT_HOMEBREW_BIN, tool)}，或确保 ${tool} 位于 PATH。`,
  );
}
