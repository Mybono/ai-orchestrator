import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import type { ClusterConfig, ClusterNode, ExoGateway } from '../types/index.js';

/**
 * Loads and validates exo-config.json from the project root.
 * Returns null if the file is absent, unreadable, or any required field
 * is missing or the wrong type. Never throws.
 */
export function loadClusterConfig(projectRoot: string): ClusterConfig | null {
  const configPath = join(projectRoot, 'exo-config.json');

  if (!existsSync(configPath)) {
    return null;
  }

  let raw: string;
  try {
    raw = readFileSync(configPath, 'utf8');
  } catch (err) {
    process.stderr.write(`[exo-config] failed to read ${configPath}: ${String(err)}\n`);
    return null;
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch (err) {
    process.stderr.write(`[exo-config] invalid JSON in ${configPath}: ${String(err)}\n`);
    return null;
  }

  if (!isRecord(parsed)) {
    process.stderr.write(`[exo-config] root value must be an object\n`);
    return null;
  }

  const combined = parsed['combined'];
  if (typeof combined !== 'boolean') {
    process.stderr.write(`[exo-config] "combined" must be a boolean\n`);
    return null;
  }

  const exoRaw = parsed['exo'];
  if (!isRecord(exoRaw)) {
    process.stderr.write(`[exo-config] "exo" must be an object\n`);
    return null;
  }

  const model = exoRaw['model'];
  if (typeof model !== 'string' || model.trim().length === 0) {
    process.stderr.write(`[exo-config] "exo.model" must be a non-empty string\n`);
    return null;
  }

  const gatewayRaw = exoRaw['gateway'];
  if (!isRecord(gatewayRaw)) {
    process.stderr.write(`[exo-config] "exo.gateway" must be an object\n`);
    return null;
  }

  const gateway = parseGateway(gatewayRaw);
  if (gateway === null) {
    process.stderr.write(
      `[exo-config] "exo.gateway" must have a non-empty string "host" and an integer "port" in range 1-65535\n`,
    );
    return null;
  }

  const nodesRaw = parsed['nodes'];
  if (!Array.isArray(nodesRaw)) {
    process.stderr.write(`[exo-config] "nodes" must be an array\n`);
    return null;
  }

  const nodes: ClusterNode[] = [];
  for (let i = 0; i < nodesRaw.length; i++) {
    const nodeRaw = nodesRaw[i];
    if (!isRecord(nodeRaw)) {
      process.stderr.write(`[exo-config] nodes[${i}] must be an object\n`);
      return null;
    }
    const node = parseNode(nodeRaw, i);
    if (node === null) {
      return null;
    }
    nodes.push(node);
  }

  return {
    combined,
    exo: { model: model.trim(), gateway },
    nodes,
  };
}

function parseGateway(raw: Record<string, unknown>): ExoGateway | null {
  const host = raw['host'];
  const port = raw['port'];
  if (typeof host !== 'string' || host.trim().length === 0) return null;
  if (typeof port !== 'number' || !Number.isInteger(port) || port < 1 || port > 65535) return null;
  return { host: host.trim(), port };
}

function parseNode(raw: Record<string, unknown>, index: number): ClusterNode | null {
  const name = raw['name'];
  const host = raw['host'];
  const portRaw = raw['port'];
  const rolesRaw = raw['roles'];

  if (typeof name !== 'string' || name.trim().length === 0) {
    process.stderr.write(`[exo-config] nodes[${index}] "name" must be a non-empty string\n`);
    return null;
  }
  if (typeof host !== 'string' || host.trim().length === 0) {
    process.stderr.write(`[exo-config] nodes[${index}] "host" must be a non-empty string\n`);
    return null;
  }
  if (
    typeof portRaw !== 'number' ||
    !Number.isInteger(portRaw) ||
    portRaw < 1 ||
    portRaw > 65535
  ) {
    process.stderr.write(
      `[exo-config] nodes[${index}] "port" must be an integer in range 1-65535\n`,
    );
    return null;
  }
  if (!isRecord(rolesRaw)) {
    process.stderr.write(`[exo-config] nodes[${index}] "roles" must be an object\n`);
    return null;
  }

  const roles: Record<string, string> = {};
  for (const [key, value] of Object.entries(rolesRaw)) {
    if (typeof value !== 'string' || value.trim().length === 0) {
      process.stderr.write(
        `[exo-config] nodes[${index}].roles["${key}"] must be a non-empty string\n`,
      );
      return null;
    }
    roles[key] = value.trim();
  }

  return { name: name.trim(), host: host.trim(), port: portRaw, roles };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
