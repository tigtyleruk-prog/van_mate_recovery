'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const childProcess = require('node:child_process');
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');

const chromePath = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const pageSource = fs.readFileSync(
  path.join(__dirname, '..', 'web', 'booking_link.html'),
  'utf8',
);

function bakeryHostedPageFixture() {
  const config = {
    ownerUid: 'bakery-owner',
    businessName: 'Business Bakes',
    isActive: true,
    services: [
      {
        id: 'bakery_custom_event_business_bakes',
        name: 'Custom Event & Business Bakes',
        requestType: 'orderRequest',
        serviceFlow: 'order',
        customerJourneyType: 'order',
        showPhoneNumber: false,
        requirePhoneNumber: false,
        showEmailAddress: false,
        requireEmailAddress: false,
        requireAddress: false,
        requestPhotos: false,
        requestFlowOptions: {
          showFulfilmentChoice: true,
          askPreferredDate: false,
          askPreferredTime: false,
          showNotes: false,
        },
        builtInQuestionSettings: {
          preferred_date: { show: false, required: false },
          preferred_time: { show: false, required: false },
        },
      },
    ],
  };
  const firebaseMock = `
    window.__mockScriptRan = true;
    window.firebase = {
      initializeApp: () => {},
      firestore: () => ({
        collection: () => ({
          doc: () => ({
            get: async () => {
              window.__mockFirestoreRead = true;
              return { exists: true, data: () => (${JSON.stringify(config)}) };
            },
          }),
        }),
      }),
      app: () => ({
        functions: () => ({
          httpsCallable: () => async (payload) => {
            window.__bookingLinkPayload = payload;
            return { data: { requestId: 'browser-regression' } };
          },
        }),
      }),
    };
  `;
  const driver = `
    <script>
      window.setTimeout(async () => {
        const result = document.createElement('pre');
        result.id = 'browserRegressionResult';
        const addressDiagnostics = [];
        const originalConsoleInfo = console.info;
        console.info = (...args) => {
          if (args[0] === '[BookingLink] order delivery address state') {
            addressDiagnostics.push(args[1]);
          }
          originalConsoleInfo.apply(console, args);
        };
        try {
          const delivery = Array.from(document.querySelectorAll('#fulfilmentChoiceGroup .choice-btn'))
            .find((button) => button.dataset.value === 'delivery');
          if (!delivery) {
            throw new Error(JSON.stringify({
              message: 'Delivery option was not rendered.',
              choices: Array.from(document.querySelectorAll('#fulfilmentChoiceGroup .choice-btn'))
                .map((button) => button.dataset.value),
              title: document.getElementById('pageTitle').textContent.trim(),
              banner: document.getElementById('banner').textContent.trim(),
              singleService: document.getElementById('singleServiceCard').textContent.trim(),
              serviceSelectValues: Array.from(document.getElementById('serviceSelect').options)
                .map((option) => option.value),
              serviceFieldsHidden: document.getElementById('serviceFields').classList.contains('hidden'),
              mockFirestoreRead: Boolean(window.__mockFirestoreRead),
              mockScriptRan: Boolean(window.__mockScriptRan),
              firebaseType: typeof window.firebase,
              mockScriptPresent: Array.from(document.scripts)
                .some((script) => script.textContent.includes('window.firebase = {')),
              mockScriptHtml: Array.from(document.scripts)
                .find((script) => script.textContent.includes('window.firebase = {'))
                ?.outerHTML.slice(0, 160),
            }));
          }
          delivery.click();
          await new Promise((resolve) => window.setTimeout(resolve, 0));
          document.getElementById('customerName').value = 'Browser Test Customer';
          document.getElementById('orderDeliveryAddress').value = '20 Delivery Street, E1 1AA';
          document.getElementById('orderDeliveryAddress').dispatchEvent(
            new Event('input', { bubbles: true }),
          );
          document.getElementById('submitButton').click();
          await new Promise((resolve) => window.setTimeout(resolve, 25));
          result.textContent = JSON.stringify({
            fulfilmentInputCount: document.querySelectorAll('#fulfilmentType').length,
            fulfilmentValue: document.getElementById('fulfilmentType').value,
            deliveryAddressVisible: !document.getElementById('orderDeliveryAddressWrap').classList.contains('hidden'),
            addressDiagnostics,
            payload: window.__bookingLinkPayload || null,
            banner: document.getElementById('banner').textContent.trim(),
          });
        } catch (error) {
          result.textContent = JSON.stringify({ error: String(error && error.message ? error.message : error) });
        }
        document.body.appendChild(result);
      }, 50);
    </script>`;
  const page = pageSource
    .replace(/\s*<script src="https:\/\/www\.gstatic\.com\/firebasejs\/[^>]+><\/script>/g, '')
    .replace('</style>', '</style>\n  <script src="/mock.js"></script>')
    .replace('</body>', `${driver}\n</body>`);
  return { page, firebaseMock };
}

function runChrome(url) {
  return new Promise((resolve, reject) => {
    const process = childProcess.spawn(chromePath, [
      '--headless=new',
      '--disable-gpu',
      '--no-sandbox',
      '--dump-dom',
      '--virtual-time-budget=1500',
      url,
    ]);
    let stdout = '';
    let stderr = '';
    process.stdout.on('data', (chunk) => { stdout += chunk; });
    process.stderr.on('data', (chunk) => { stderr += chunk; });
    process.on('error', reject);
    process.on('close', (code) => {
      if (code === 0) {
        resolve(stdout);
      } else {
        reject(new Error(`Chrome exited with ${code}: ${stderr}`));
      }
    });
  });
}

test('Bakery delivery writes one canonical fulfilment value through to submission', async () => {
  assert.equal(fs.existsSync(chromePath), true, 'Google Chrome is required for the hosted-page regression.');
  const fixture = bakeryHostedPageFixture();
  assert.doesNotThrow(() => new Function(fixture.firebaseMock));
  const servedPaths = [];
  const server = http.createServer((request, response) => {
    servedPaths.push(request.url);
    if (request.url === '/mock.js') {
      response.writeHead(200, { 'Content-Type': 'application/javascript; charset=utf-8' });
      response.end(fixture.firebaseMock);
      return;
    }
    response.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    response.end(fixture.page);
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();

  try {
    const output = await runChrome(`http://127.0.0.1:${address.port}/booking_link.html?owner=bakery-owner`);
    assert.ok(servedPaths.includes('/mock.js'), `The browser did not load the Firebase mock: ${servedPaths.join(', ')}`);
    const match = output.match(/<pre id="browserRegressionResult">([\s\S]*?)<\/pre>/);
    assert.ok(match, 'The browser fixture did not complete.');
    const result = JSON.parse(match[1]);

    assert.equal(result.error, undefined);
    assert.equal(result.fulfilmentInputCount, 1);
    assert.equal(result.fulfilmentValue, 'delivery');
    assert.equal(result.deliveryAddressVisible, true);
    assert.equal(result.banner, '');
    assert.equal(result.payload.fulfilmentType, 'delivery');
    assert.equal(result.payload.deliveryAddress, '20 Delivery Street, E1 1AA');
    const addressStages = result.addressDiagnostics.map((entry) => entry.stage);
    assert.ok(addressStages.includes('after_input'));
    assert.ok(addressStages.includes('before_validation'));
    assert.ok(addressStages.includes('validator'));
    assert.ok(addressStages.includes('payload'));
    assert.equal(
      result.addressDiagnostics.find((entry) => entry.stage === 'after_input').inputHasValue,
      true,
    );
    assert.equal(
      result.addressDiagnostics.find((entry) => entry.stage === 'validator').validatorHasValue,
      true,
    );
    assert.equal(
      result.addressDiagnostics.find((entry) => entry.stage === 'payload').payloadHasValue,
      true,
    );
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});
