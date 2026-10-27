// Parse source as data. Never load an addon chunk or emulate game globals.
const fs = require('node:fs');
const luaparse = require(process.env.PR_LUAPARSE);

function member(node) {
  if (!node) return null;
  if (node.type === 'Identifier') return node.name === 'T' ? 'DFRL.tools' : node.name;
  if (node.type === 'MemberExpression') {
    const base = member(node.base);
    return base && `${base}.${node.identifier.name}`;
  }
  if (node.type === 'IndexExpression' && node.index.type === 'StringLiteral') {
    const base = member(node.base);
    return base && `${base}.${node.index.value}`;
  }
  return null;
}

function parse(source) {
  // Latin-1 preserves Lua bytes, including non-ASCII localization and escapes.
  return luaparse.parse(Buffer.from(source, 'utf8').toString('latin1'), {
    luaVersion: '5.1',
    encodingMode: 'pseudo-latin1',
    locations: true,
    ranges: true,
    comments: false,
  });
}

function walk(node, callback, parent, key) {
  if (!node || typeof node !== 'object') return;
  if (Array.isArray(node)) {
    for (const item of node) walk(item, callback, parent, key);
    return;
  }
  if (!node.type) return;
  callback(node, parent, key);
  for (const [childKey, value] of Object.entries(node)) {
    if (childKey !== 'loc' && childKey !== 'range') walk(value, callback, node, childKey);
  }
}

function inventory(source) {
  const tree = parse(source);
  const strings = [];
  const definitions = [];
  const reads = [];
  const calls = [];
  walk(tree, (node, parent, key) => {
    const line = node.loc.start.line;
    if (node.type === 'StringLiteral') strings.push({ value: node.value, line });
    if (node.type === 'FunctionDeclaration' && node.identifier) {
      definitions.push({ name: member(node.identifier), line });
    }
    if (node.type === 'AssignmentStatement') {
      node.variables.forEach((variable, index) => {
        if (node.init[index]?.type === 'FunctionDeclaration') {
          definitions.push({ name: member(variable), line });
        }
      });
    }
    if (node.type === 'CallExpression') calls.push({ name: member(node.base), line });
    if (node.type === 'MemberExpression' || node.type === 'IndexExpression') {
      const isBase =
        key === 'base' && /^(Member|Index)Expression$/.test(parent?.type) && member(parent);
      const isDefinition = parent?.type === 'FunctionDeclaration' && key === 'identifier';
      const isWrite = parent?.type === 'AssignmentStatement' && key === 'variables';
      if (!isBase && !isDefinition && !isWrite) reads.push({ name: member(node), line });
    }
  });
  return { strings, definitions, reads, calls };
}

module.exports = { parse, walk, member, inventory };

if (require.main === module) {
  const sources = JSON.parse(fs.readFileSync(0, 'utf8'));
  const result = {};
  for (const [name, source] of Object.entries(sources)) {
    try {
      result[name] = inventory(source);
    } catch (error) {
      error.message = `${name}: ${error.message}`;
      throw error;
    }
  }
  process.stdout.write(JSON.stringify(result));
}
