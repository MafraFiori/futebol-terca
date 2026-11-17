// srv/lib/fixed-values.js
// Valores fixos (enum) para os smart controls:
//  - FixedValues: lista de valores lida dos enums do modelo (sem tabela)
//  - <campo>_text: texto (@title) preenchido após cada READ
// Uso no serviço:  require('./lib/fixed-values').register(this)
const cds = require('@sap/cds');

const NS = 'futebol.';

function enumLists() {
  const out = [];
  for (const [name, def] of Object.entries(cds.model.definitions)) {
    if (!name.startsWith(NS) || def.kind !== 'type' || !def.enum) continue;
    Object.entries(def.enum).forEach(([code, v], i) =>
      out.push({ list: name.slice(NS.length), code, text: v['@title'] ?? code, ordem: i + 1 }));
  }
  return out;
}

function filterValue(where, prop) {
  if (!where) return;
  // forma CXN (OData $filter): [{ref:[prop]}, '=', {val}]
  const i = where.findIndex((x) => x?.ref?.[0] === prop);
  if (i >= 0) return where[i + 2]?.val;
  // forma objeto (chamadas internas): [{ prop: valor }]
  const obj = where.find((x) => x && typeof x === 'object' && !x.ref && prop in x);
  return obj?.[prop];
}

function register(srv) {
  if (srv.entities.FixedValues) {
    srv.on('READ', 'FixedValues', (req) => {
      const list = filterValue(req.query.SELECT.where, 'list');
      const rows = enumLists();
      return list ? rows.filter((r) => r.list === list) : rows;
    });
  }
  srv.after('READ', '*', (data, req) => {
    const elems = req.target?.elements;
    if (!elems) return;
    const enumEls = Object.entries(elems).filter(([el, d]) => d.enum && `${el}_text` in elems);
    if (!enumEls.length) return;
    for (const row of [].concat(data || [])) {
      if (!row) continue;
      for (const [el, d] of enumEls) if (el in row) row[`${el}_text`] = d.enum[row[el]]?.['@title'] ?? row[el];
    }
  });
}

module.exports = { register, enumLists };
