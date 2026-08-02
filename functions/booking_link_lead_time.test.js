const test = require('node:test');
const assert = require('node:assert/strict');

const { __test__ } = require('./index.js');

test('booking link preferred timing validator honours service lead time', () => {
  const now = new Date(2026, 6, 25, 10, 0, 0, 0);

  assert.equal(
    __test__.validatePreferredBookingWindow({
      preferredDate: new Date(2026, 6, 25),
      preferredTimeWindow: '15:00',
      preferredIsFlexible: false,
      noticeHours: 24,
      now,
    }),
    'This service needs more notice. Please choose a later date or time.',
  );
  assert.equal(
    __test__.validatePreferredBookingWindow({
      preferredDate: new Date(2026, 6, 26),
      preferredTimeWindow: '09:30',
      preferredIsFlexible: false,
      noticeHours: 24,
      now,
    }),
    'This service needs more notice. Please choose a later date or time.',
  );
  assert.equal(
    __test__.validatePreferredBookingWindow({
      preferredDate: new Date(2026, 6, 26),
      preferredTimeWindow: '10:15',
      preferredIsFlexible: false,
      noticeHours: 24,
      now,
    }),
    null,
  );
  assert.equal(
    __test__.validatePreferredBookingWindow({
      preferredDate: new Date(2026, 6, 26),
      preferredTimeWindow: '',
      preferredIsFlexible: true,
      noticeHours: 48,
      now,
    }),
    'This service needs more notice. Please choose a later date or time.',
  );
  assert.equal(
    __test__.validatePreferredBookingWindow({
      preferredDate: null,
      preferredTimeWindow: '',
      preferredIsFlexible: false,
      noticeHours: 24,
      now,
    }),
    null,
  );
});
