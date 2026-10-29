// CI-only lexical analysis for the native Lua 5.0 closure limit. No Lua executes.
function upvalueLimits(tree, limit = 32) {
  const functions = [];
  const chunk = { parent: null, captures: new Set() };
  const scope = (parent, owner) => ({ parent, owner, locals: new Map() });
  function declare(environment, name) {
    environment.locals.set(name, { name, owner: environment.owner });
  }
  function reference(environment, name) {
    let binding;
    for (let current = environment; current; current = current.parent) {
      binding = current.locals.get(name);
      if (binding) break;
    }
    if (!binding) return; // Globals do not consume an upvalue in Lua 5.0.
    // Intermediate closures also carry a capture used only by a deeper closure.
    for (let owner = environment.owner; owner !== binding.owner; owner = owner.parent)
      owner.captures.add(binding);
  }
  function block(body, environment) {
    visit(body, scope(environment, environment.owner));
  }
  function visit(node, environment) {
    if (!node || typeof node !== 'object') return;
    if (Array.isArray(node)) {
      for (const item of node) visit(item, environment);
      return;
    }
    switch (node.type) {
      case 'Identifier':
        reference(environment, node.name);
        return;
      case 'LocalStatement':
        // RHS closures see the previous binding, even when the name is reused.
        visit(node.init, environment);
        for (const variable of node.variables) declare(environment, variable.name);
        return;
      case 'FunctionDeclaration': {
        if (node.isLocal) declare(environment, node.identifier.name);
        else visit(node.identifier, environment);
        const owner = { node, parent: environment.owner, captures: new Set() };
        functions.push(owner);
        const body = scope(environment, owner);
        if (node.identifier?.type === 'MemberExpression' && node.identifier.indexer === ':')
          declare(body, 'self');
        for (const parameter of node.parameters)
          declare(body, parameter.type === 'VarargLiteral' ? 'arg' : parameter.name);
        visit(node.body, body);
        return;
      }
      case 'MemberExpression':
        visit(node.base, environment); // A literal field name is not a variable.
        return;
      case 'TableKeyString':
        visit(node.value, environment);
        return;
      case 'ForNumericStatement': {
        visit([node.start, node.end, node.step], environment);
        const body = scope(environment, environment.owner);
        declare(body, node.variable.name);
        visit(node.body, body);
        return;
      }
      case 'ForGenericStatement': {
        visit(node.iterators, environment);
        const body = scope(environment, environment.owner);
        for (const variable of node.variables) declare(body, variable.name);
        visit(node.body, body);
        return;
      }
      case 'RepeatStatement': {
        const body = scope(environment, environment.owner);
        visit(node.body, body);
        visit(node.condition, body); // Repeat locals remain visible to until.
        return;
      }
      case 'WhileStatement':
        visit(node.condition, environment);
        block(node.body, environment);
        return;
      case 'DoStatement':
        block(node.body, environment);
        return;
      case 'IfStatement':
        for (const clause of node.clauses) {
          visit(clause.condition, environment);
          block(clause.body, environment);
        }
        return;
      default:
        for (const [key, value] of Object.entries(node))
          if (key !== 'loc' && key !== 'range') visit(value, environment);
    }
  }
  visit(tree.body, scope(null, chunk));
  return functions
    .filter((owner) => owner.captures.size > limit)
    .map((owner) => ({
      line: owner.node.loc.start.line,
      count: owner.captures.size,
      names: [...owner.captures].map((binding) => binding.name),
    }));
}

module.exports = { upvalueLimits };
