'use strict';

function readBusinessProfileId(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function recordBelongsToBusiness(record, businessProfileId) {
  const recordProfileId = readBusinessProfileId(record && record.businessProfileId);
  const targetProfileId = readBusinessProfileId(businessProfileId);
  return Boolean(recordProfileId && targetProfileId) &&
    recordProfileId === targetProfileId;
}

function isAmbiguousBusinessRecord(record) {
  return !readBusinessProfileId(record && record.businessProfileId);
}

module.exports = {
  isAmbiguousBusinessRecord,
  readBusinessProfileId,
  recordBelongsToBusiness,
};
