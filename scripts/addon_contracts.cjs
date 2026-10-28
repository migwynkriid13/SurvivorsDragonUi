// Conservative source contracts. No addon chunks or game APIs execute here.
const fs = require('node:fs');
const { parse, walk, member } = require('./lua_inventory.cjs');

const text = (node) =>
  node?.type === 'StringLiteral' ? Buffer.from(node.value, 'latin1').toString('utf8') : undefined;
const key = (field) =>
  field.type === 'TableKeyString' ? field.key.name : (text(field.key) ?? field.key?.value);

function model(source) {
  const tree = parse(source);
  const nodes = [];
  walk(tree, (node) => nodes.push(node));
  const bindings = new Map();
  const tables = new Map();
  const aliases = new Map();
  const declared = new Set();
  function bind(name, value) {
    declared.add(name);
    if (!bindings.has(name)) bindings.set(name, []);
    if (value) bindings.get(name).push(value);
    if (value?.type === 'TableConstructorExpression') tables.set(name, value);
  }
  for (const node of nodes) {
    if (node.type === 'LocalStatement' || node.type === 'AssignmentStatement') {
      node.variables.forEach((variable, index) => {
        if (variable.type === 'Identifier') {
          bind(variable.name, node.init[index]);
          const alias = member(node.init[index]);
          if (alias?.startsWith('DFRL.')) aliases.set(variable.name, alias);
        }
        const target = member(variable);
        if (target?.startsWith('DFRL.') && node.init[index]?.type === 'Identifier') {
          aliases.set(node.init[index].name, target);
        }
      });
    }
    if (node.type === 'FunctionDeclaration') {
      if (node.identifier?.type === 'Identifier') bind(node.identifier.name, node);
      for (const parameter of node.parameters) {
        if (parameter.name) declared.add(parameter.name);
      }
    }
    if (node.type === 'ForGenericStatement') {
      node.variables.forEach((variable, index) => {
        bind(variable.name);
        const iterator = node.iterators[0];
        if (index === 1 && ['pairs', 'ipairs'].includes(iterator?.base?.name)) {
          bindings
            .get(variable.name)
            .push({ type: 'CollectionValues', base: iterator.arguments[0] });
        }
      });
    }
    if (node.type === 'ForNumericStatement') bind(node.variable.name);
  }
  function path(node) {
    const name = member(node);
    if (!name) return null;
    const [head, ...tail] = name.split('.');
    return [aliases.get(head) || head, ...tail].join('.');
  }
  function tableValues(node, seen) {
    if (node?.type === 'Identifier') return tableValues(tables.get(node.name), seen);
    if (node?.type !== 'TableConstructorExpression') return [];
    return node.fields.flatMap((field) => strings(field.value, seen));
  }
  function strings(node, seen = new Set()) {
    if (!node || seen.has(node)) return [];
    const next = new Set(seen).add(node);
    if (text(node) !== undefined) return [text(node)];
    if (node.type === 'Identifier') {
      return (bindings.get(node.name) || []).flatMap((value) => strings(value, next));
    }
    if (node.type === 'CollectionValues') return tableValues(node.base, next);
    if (node.type === 'LogicalExpression') {
      return [...strings(node.left, next), ...strings(node.right, next)];
    }
    if (node.type === 'BinaryExpression' && node.operator === '..') {
      const left = strings(node.left, next);
      const right = strings(node.right, next);
      if (left.length * right.length > 256) return [];
      return left.flatMap((prefix) => right.map((suffix) => prefix + suffix));
    }
    if (node.type === 'IndexExpression') return tableValues(node.base, next);
    if (node.type === 'MemberExpression') {
      return nodes
        .filter((field) => field.type === 'TableKeyString' && key(field) === node.identifier.name)
        .flatMap((field) => strings(field.value, next));
    }
    return [];
  }
  return { nodes, tables, bindings, declared, path, strings };
}

function analyze(sources, captions = []) {
  const models = Object.fromEntries(
    Object.entries(sources).map(([file, source]) => {
      try {
        return [file, model(source)];
      } catch (error) {
        error.message = `${file}: ${error.message}`;
        throw error;
      }
    }),
  );
  const failures = [];
  const dynamic = [];
  const functions = new Set();
  const globals = new Set();
  const literals = new Set();
  const declarations = new Map();
  const defaults = models['core/display.lua']?.tables.get('defaults');
  if (!defaults) throw Error('core/display.lua: missing unique display defaults table');
  const settings = new Set(defaults.fields.map(key));
  const consumed = new Map([...settings].map((name) => [name, []]));
  const normalized = new Set();
  const registrations = new Map();
  const namespaces = /^DFRL\.(tools|display|layout|locale|sct)\.[^.]+$/;

  for (const [file, data] of Object.entries(models)) {
    for (const node of data.nodes) {
      if (node.type === 'FunctionDeclaration' && node.identifier) {
        functions.add(data.path(node.identifier));
        if (!node.isLocal && node.identifier.type === 'Identifier')
          globals.add(node.identifier.name);
      }
      if (node.type === 'AssignmentStatement') {
        node.variables.forEach((variable, index) => {
          if (node.init[index]?.type === 'FunctionDeclaration') functions.add(data.path(variable));
        });
      }
      if (node.type === 'TableConstructorExpression') {
        const keys = new Set();
        let arrayIndex = 0;
        for (const field of node.fields) {
          const value = field.type === 'TableValue' ? ++arrayIndex : key(field);
          if (typeof value !== 'string' && typeof value !== 'number') continue;
          if (keys.has(value))
            failures.push(
              `${file}:${field.loc.start.line}: duplicate table key ${JSON.stringify(value)}`,
            );
          keys.add(value);
        }
      }
      if (node.type === 'StringLiteral' && file !== 'localization/data.lua')
        literals.add(text(node));
      if (
        node.type === 'FunctionDeclaration' &&
        node.identifier?.name === 'Normalize' &&
        file === 'core/display.lua'
      ) {
        walk(node, (child) => {
          if (child.type === 'TableKeyString') {
            normalized.add(key(child));
            if (
              child.value.type === 'CallExpression' &&
              child.value.base.name === 'Read' &&
              text(child.value.arguments[1]) !== key(child)
            ) {
              failures.push(
                `${file}:${child.loc.start.line}: Normalize reads the wrong key for ${key(child)}`,
              );
            }
          }
        });
      }
    }
    declarations.set(file, data.declared);
  }
  for (const name of settings) {
    if (!normalized.has(name))
      failures.push(`core/display.lua: setting ${name} is missing from Normalize`);
  }
  for (const name of normalized) {
    if (!settings.has(name))
      failures.push(`core/display.lua: Normalize contains unknown setting ${name}`);
  }
  const ranges = models['core/display.lua'].tables.get('ranges');
  for (const field of ranges?.fields || []) {
    if (!settings.has(key(field)))
      failures.push(`core/display.lua: range for unknown setting ${key(field)}`);
  }

  const layoutFields = new Set();
  for (const node of models['core/layout.lua']?.nodes || []) {
    if (node.type === 'MemberExpression' && /(^|\.)options$/.test(member(node.base) || '')) {
      layoutFields.add(node.identifier.name);
    }
  }
  function callbackContract(callback, label, data, file, location) {
    if (!callback || ['NilLiteral', 'FunctionDeclaration'].includes(callback.type)) return;
    if (
      ['StringLiteral', 'NumericLiteral', 'BooleanLiteral', 'TableConstructorExpression'].includes(
        callback.type,
      )
    ) {
      failures.push(`${location}: ${label} requires a function or nil callback`);
    } else if (
      callback.type === 'Identifier' &&
      !declarations.get(file).has(callback.name) &&
      !globals.has(callback.name)
    ) {
      failures.push(`${location}: callback ${callback.name} has no Lua declaration`);
    } else if (
      callback.type === 'Identifier' &&
      (data.bindings.get(callback.name) || []).length > 0 &&
      data.bindings
        .get(callback.name)
        .every((value) => /^(String|Numeric|Boolean|Nil)Literal$/.test(value.type))
    ) {
      failures.push(`${location}: callback ${callback.name} is assigned only non-functions`);
    } else if (
      callback.type !== 'Identifier' ||
      !(data.bindings.get(callback.name) || []).some(
        (value) => value.type === 'FunctionDeclaration',
      )
    ) {
      dynamic.push({
        location,
        api: label,
        reason: 'dynamic callback or unresolved function type; review required',
      });
    }
  }

  for (const [file, data] of Object.entries(models)) {
    for (const node of data.nodes.filter((item) => item.type === 'CallExpression')) {
      const api = data.path(node.base);
      const location = `${file}:${node.loc.start.line}`;
      const method = node.base.type === 'MemberExpression' ? node.base.identifier.name : null;
      if (namespaces.test(api || '') && !functions.has(api))
        failures.push(`${location}: unknown shared API ${api}`);
      if (api === 'DFRL.display.Get' || api === 'DFRL.display.Set') {
        const argument = node.arguments[0];
        const names = [...new Set(data.strings(argument))];
        const literal = text(argument);
        if (literal !== undefined && !settings.has(literal))
          failures.push(`${location}: unknown setting ${literal}`);
        if (literal === undefined)
          dynamic.push({ location, api, candidates: names.filter((name) => settings.has(name)) });
        if (api.endsWith('.Get') && file !== 'core/display.lua') {
          for (const name of names) {
            if (settings.has(name)) consumed.get(name).push(location);
          }
        }
      }
      if (api === 'DFRL.NewMod' || api === 'DFRL.layout.Register') {
        const id = text(node.arguments[0]);
        if (id !== undefined) {
          const identity = api + ':' + id;
          if (registrations.has(identity))
            failures.push(
              `${location}: duplicate registration ${identity}; first at ${registrations.get(identity)}`,
            );
          registrations.set(identity, location);
        } else dynamic.push({ location, api, reason: 'dynamic registration ID' });
      }
      if (api === 'DFRL.layout.Register' && layoutFields.size > 0) {
        const options = node.arguments[3];
        if (options?.type === 'TableConstructorExpression') {
          for (const field of options.fields) {
            const name = key(field);
            if (name !== undefined && !layoutFields.has(name)) {
              failures.push(`${location}: Layout option ${name} has no reader in core/layout.lua`);
            }
            if (/^on[A-Z]/.test(name || '') || name === 'refreshRegion') {
              callbackContract(field.value, `Layout option ${name}`, data, file, location);
            }
          }
        } else if (options && options.type !== 'NilLiteral') {
          dynamic.push({ location, api, reason: 'dynamic Layout options; review required' });
        }
      }
      const callbackIndex =
        method === 'SetScript' || api === 'DFRL.layout.ListenVisibility'
          ? 1
          : api === 'DFRL.layout.Register' || api === 'DFRL.NewMod' || api === 'HookScript'
            ? 2
            : api === 'hooksecurefunc'
              ? 1
              : [
                    'DFRL.display.Listen',
                    'DFRL.locale.Listen',
                    'DFRL.sct.Listen',
                    'DFRL.layout.SetEditorVisibilityHandler',
                  ].includes(api)
                ? 0
                : null;
      if (callbackIndex === null) continue;
      callbackContract(node.arguments[callbackIndex], api || method, data, file, location);
    }
  }
  return {
    failures,
    unusedSettings: [...consumed]
      .filter(([, readers]) => readers.length === 0)
      .map(([name]) => name)
      .sort(),
    settingReaders: Object.fromEntries(consumed),
    unusedCaptions: captions.filter((caption) => !literals.has(caption)).sort(),
    dynamic,
    registrations: Object.fromEntries(registrations),
  };
}

function extract(source, names) {
  const tree = parse(source);
  const found = new Map(names.map((name) => [name, []]));
  walk(tree, (node) => {
    const declared =
      node.type === 'FunctionDeclaration' && node.isLocal
        ? [node.identifier?.name]
        : node.type === 'LocalStatement'
          ? node.variables.map((variable) => variable.name)
          : [];
    for (const name of declared) {
      if (found.has(name)) found.get(name).push(node);
    }
  });
  const chunks = [];
  const included = new Set();
  for (const [name, nodes] of found) {
    if (nodes.length !== 1)
      throw Error(`UI test seam ${name}: expected one production declaration, got ${nodes.length}`);
    if (included.has(nodes[0])) continue;
    included.add(nodes[0]);
    chunks.push(
      Buffer.from(source, 'utf8')
        .subarray(...nodes[0].range)
        .toString('utf8'),
    );
  }
  return chunks.join('\n') + '\nreturn ' + names[names.length - 1] + '\n';
}

module.exports = { analyze, extract };
if (require.main === module) {
  const input = JSON.parse(fs.readFileSync(0, 'utf8'));
  const output = input.extract
    ? extract(input.source, input.extract)
    : analyze(input.sources, input.captions);
  process.stdout.write(JSON.stringify(output));
}
