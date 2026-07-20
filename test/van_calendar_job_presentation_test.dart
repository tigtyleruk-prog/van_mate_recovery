import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/helpers/van_calendar_job_presentation.dart';
import 'package:van_mate_app/features/van_mate/pages/driver_customer_reply_mock_page.dart';

DriverCustomerReplyMockData _job({
  String customerJourneyType = 'quote',
  String requestType = '',
  String fulfilmentType = '',
  DateTime? dropOffDate,
  String dropOffTime = '',
  DateTime? pickUpDate,
  String pickUpTime = '',
}) {
  return DriverCustomerReplyMockData(
    jobId: 'calendar-job',
    customerName: 'Customer',
    jobTitle: 'Cake Orders',
    scheduledAt: DateTime.parse('2026-07-13T09:00:00.000'),
    jobDateLabel: '13 Jul 2026',
    jobTimeLabel: '09:00',
    address: '',
    phoneNumber: '',
    exactPinShared: false,
    checklistResponses: const <DriverChecklistResponse>[],
    customQuestionResponses: const <DriverCustomQuestionResponse>[],
    additionalNotes: '',
    status: 'scheduled',
    requestStatus: 'confirmed',
    calendarStatus: 'scheduled',
    requestType: requestType,
    customerJourneyType: customerJourneyType,
    fulfilmentType: fulfilmentType,
    dropOffDate: dropOffDate,
    dropOffTime: dropOffTime,
    pickUpDate: pickUpDate,
    pickUpTime: pickUpTime,
  );
}

void main() {
  test(
    'collection orders get a distinct calendar label and completion action',
    () {
      final job = _job(
        requestType: 'orderRequest',
        fulfilmentType: 'collection',
      );

      expect(job.calendarJobKind, VanCalendarJobKind.collectionOrder);
      expect(job.allowsParallelCalendarScheduling, isTrue);
      expect(vanCalendarDisplayJobTitle(job), 'Collection – Cake Orders');
      expect(vanCalendarAccentForJob(job), vanCalendarDefaultAccent);
      expect(vanCalendarCompletionActionLabel(job), 'Mark collected');
    },
  );

  test('delivery orders retain default calendar colour and conflict guard', () {
    final job = _job(requestType: 'orderRequest', fulfilmentType: 'delivery');

    expect(job.calendarJobKind, VanCalendarJobKind.deliveryOrder);
    expect(job.allowsParallelCalendarScheduling, isFalse);
    expect(vanCalendarDisplayJobTitle(job), 'Delivery – Cake Orders');
    expect(vanCalendarAccentForJob(job), vanCalendarDefaultAccent);
    expect(vanCalendarCompletionActionLabel(job), 'Mark delivered');
  });

  test('drop-off and pickup flow uses one shared transfer presentation', () {
    final job = _job(
      requestType: 'dropOffPickupRequest',
      dropOffDate: DateTime(2026, 7, 27),
      dropOffTime: '09:30',
      pickUpDate: DateTime(2026, 7, 27),
      pickUpTime: '17:30',
    );

    expect(job.calendarJobKind, VanCalendarJobKind.dropOffPickup);
    expect(job.allowsParallelCalendarScheduling, isTrue);
    expect(vanCalendarDisplayJobTitle(job), 'Drop-off / Pick-up – Cake Orders');
    expect(vanCalendarAccentForJob(job), vanCalendarDefaultAccent);

    final actions = vanCalendarActionProjections(job);
    expect(actions, hasLength(2));
    expect(actions[0].kind, VanCalendarActionKind.dropOff);
    expect(actions[0].label, 'Customer drop-off');
    expect(actions[0].start, DateTime(2026, 7, 27, 9, 30));
    expect(actions[0].showBookingDuration, isFalse);
    expect(actions[0].visualOccupancyMinutes, 1);
    expect(actions[1].kind, VanCalendarActionKind.pickUp);
    expect(actions[1].label, 'Customer collection');
    expect(actions[1].start, DateTime(2026, 7, 27, 17, 30));
    expect(actions[1].showBookingDuration, isFalse);
    expect(actions[1].visualOccupancyMinutes, 1);
  });

  test(
    'calendar accent follows journey while operational title stays intact',
    () {
      final booking = _job(
        customerJourneyType: 'booking',
        requestType: 'dropOffPickupRequest',
        dropOffDate: DateTime(2026, 7, 27),
        dropOffTime: '09:30',
        pickUpDate: DateTime(2026, 7, 27),
        pickUpTime: '16:00',
      );
      final order = _job(
        customerJourneyType: 'order',
        requestType: 'orderRequest',
        fulfilmentType: 'collection',
      );

      expect(vanCalendarAccentForJob(booking), const Color(0xFF9B7CFF));
      expect(vanCalendarAccentForJob(order), const Color(0xFFFFA24C));
      expect(vanCalendarDisplayJobTitle(order), contains('Collection'));
    },
  );

  test('normal jobs do not create transfer action projections', () {
    expect(vanCalendarActionProjections(_job()), isEmpty);
  });

  test('legacy order without fulfilment type keeps standard behaviour', () {
    final job = _job(requestType: 'orderRequest');

    expect(job.calendarJobKind, VanCalendarJobKind.standard);
    expect(job.allowsParallelCalendarScheduling, isFalse);
    expect(vanCalendarDisplayJobTitle(job), 'Cake Orders');
  });
}
