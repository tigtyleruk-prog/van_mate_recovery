import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/van_business_profile.dart';
import '../models/van_customer_request_flow.dart';
import '../models/van_customer_journey.dart';
import '../models/van_custom_job_question.dart';
import '../models/van_job_service.dart';
import '../models/van_service_handover.dart';
import 'van_firestore_payload_builder.dart';
import 'van_firebase_debug_logging.dart';
import 'van_user_cloud_service.dart';

class VanBookingLinkCloudService {
  VanBookingLinkCloudService._({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final VanBookingLinkCloudService instance =
      VanBookingLinkCloudService._();

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _publicConfig(String ownerUid) {
    return _firestore.collection('public_booking_links').doc(ownerUid.trim());
  }

  Future<void> savePublicConfig({
    required String ownerUid,
    String? publicConfigId,
    String? businessProfileId,
    required String title,
    required bool isActive,
    required VanBusinessProfile profile,
    required List<VanJobService> activeServices,
    required Map<String, VanCustomJobQuestion> questionLookup,
    String source = 'van_mate.booking_link_publish',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    final normalizedPublicConfigId = publicConfigId?.trim().isNotEmpty == true
        ? publicConfigId!.trim()
        : normalizedOwnerUid;
    if (normalizedOwnerUid.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final rawBusinessName = profile.businessName.trim();
    final normalizedBusinessName =
        rawBusinessName.toLowerCase() ==
            VanBusinessProfile.defaults().businessName.toLowerCase()
        ? ''
        : rawBusinessName;
    final payload = buildVanCloudDocPayload(
      id: normalizedPublicConfigId,
      ownerUid: normalizedOwnerUid,
      source: source,
      createdAt: now,
      updatedAt: now,
      data: <String, dynamic>{
        'title': title.trim(),
        'publicConfigId': normalizedPublicConfigId,
        'businessProfileId': businessProfileId?.trim() ?? '',
        'isActive': isActive,
        'businessName': normalizedBusinessName,
        'contactName': profile.contactName.trim(),
        'phone': profile.phone.trim(),
        'email': profile.email.trim(),
        'logoPath': profile.logoPath?.trim() ?? '',
        'logoUrl': profile.logoUrl?.trim() ?? '',
        'introText': 'Choose a service and tell us what you need.',
        'services': activeServices
            .map(
              (service) => <String, dynamic>{
                'id': service.id,
                'name': service.name.trim(),
                'description': service.description.trim(),
                'starterPackId': service.starterPackId,
                'starterTemplateId': service.starterTemplateId,
                'customerMessage': service.customerMessage.trim(),
                'appointmentDurationMinutes':
                    service.appointmentDurationMinutes,
                'noticeHours': service.noticeHours,
                'maxBookingsPerDay': service.maxBookingsPerDay,
                'pricingMode': service.pricingMode,
                'fixedPriceAmount': service.fixedPriceAmount,
                'fromPriceAmount': service.fromPriceAmount,
                'requestType': service.serviceFlow.requestType.storageKey,
                'serviceFlow': service.serviceFlow.storageKey,
                'customerJourneyType': service.customerJourneyType.storageKey,
                'serviceCapabilityIds': service.serviceCapabilityIds,
                'capabilityContract': service.capabilityContract.toJson(),
                'startHandover': service.effectiveHandover.start.storageKey,
                'endHandover': service.effectiveHandover.end.storageKey,
                'allowedStartHandoverOptions': service
                    .effectiveHandover
                    .allowedStarts
                    .map((value) => value.storageKey)
                    .toList(growable: false),
                'allowedEndHandoverOptions': service
                    .effectiveHandover
                    .allowedEnds
                    .map((value) => value.storageKey)
                    .toList(growable: false),
                'allowCustomerDropOff': service.allowCustomerDropOff,
                'allowBusinessCollection': service.allowBusinessCollection,
                'allowCustomerCollection': service.allowCustomerCollection,
                'allowBusinessReturn': service.allowBusinessReturn,
                'allowBusinessDelivery': service.allowBusinessDelivery,
                'businessDropOffInstructions':
                    service.businessDropOffInstructions,
                'businessCollectionInstructions':
                    service.businessCollectionInstructions,
                'requestFlowOptions': service.effectiveRequestFlowOptions
                    .toJson(),
                'requireAddress': service.requireAddress,
                'showAddress': service.showsBuiltInQuestion('address'),
                'showPhoneNumber': service.showsBuiltInQuestion('phone'),
                'requirePhoneNumber': service.requiresBuiltInQuestion(
                  'phone',
                  legacyDefault: true,
                ),
                'showEmailAddress': service.showsBuiltInQuestion('email'),
                'requireEmailAddress': service.requiresBuiltInQuestion('email'),
                'requestPhotos': service.requestPhotos,
                'maxCustomerPhotos': service.maxCustomerPhotos,
                'builtInQuestionSettings': service.builtInQuestionSettings,
                'requestExactPinAfterQuoteAccepted':
                    service.requestExactPinAfterQuoteAccepted,
                'quoteExtraDefaults': service.quoteExtraDefaults.toJson(),
                'extraChargeUnits': service.extraChargeUnits,
                'linkedQuestions': service.linkedQuestionIds
                    .where(
                      (id) => !service.disabledLinkedQuestionIds.contains(id),
                    )
                    .map((id) => questionLookup[id])
                    .whereType<VanCustomJobQuestion>()
                    .where(
                      (question) => question.isActive && !question.isArchived,
                    )
                    .map(
                      (question) => <String, dynamic>{
                        'id': question.id,
                        'questionText': question.questionText.trim(),
                        'helperText': question.helperText.trim(),
                        'libraryQuestionId': question.libraryQuestionId,
                        'answerType': question.answerType.storageKey,
                        'category': question.category?.storageKey ?? '',
                        'choiceOptions': question.choiceOptions,
                        'optional': service.optionalQuestionIds.contains(
                          question.id,
                        ),
                      },
                    )
                    .toList(growable: false),
              },
            )
            .toList(growable: false),
      },
    );

    logVanFirebaseWriteStart(
      collectionPath: 'public_booking_links',
      docId: normalizedPublicConfigId,
      uid: normalizedOwnerUid,
      source: source,
    );
    try {
      await VanUserCloudService.instance.ensureUserDocument(
        uid: normalizedOwnerUid,
        authType: 'anonymous',
        source: source,
      );
      await _publicConfig(
        normalizedPublicConfigId,
      ).set(sanitizeVanFirestoreMap(payload), SetOptions(merge: true));
      logVanFirebaseWriteSuccess(
        collectionPath: 'public_booking_links',
        docId: normalizedPublicConfigId,
        uid: normalizedOwnerUid,
        source: source,
      );
    } catch (error) {
      logVanFirebaseWriteFailure(
        collectionPath: 'public_booking_links',
        docId: normalizedPublicConfigId,
        uid: normalizedOwnerUid,
        error: error,
        source: source,
      );
      rethrow;
    }
  }

  Future<void> syncBusinessProfileBranding({
    required String ownerUid,
    required VanBusinessProfile profile,
    String source = 'van_mate.booking_link_profile_sync',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty) {
      return;
    }

    final rawBusinessName = profile.businessName.trim();
    final normalizedBusinessName =
        rawBusinessName.toLowerCase() ==
            VanBusinessProfile.defaults().businessName.toLowerCase()
        ? ''
        : rawBusinessName;
    final now = DateTime.now();
    final payload = buildVanCloudDocPayload(
      id: normalizedOwnerUid,
      ownerUid: normalizedOwnerUid,
      source: source,
      createdAt: now,
      updatedAt: now,
      data: <String, dynamic>{
        'businessName': normalizedBusinessName,
        'contactName': profile.contactName.trim(),
        'phone': profile.phone.trim(),
        'email': profile.email.trim(),
        'logoPath': profile.logoPath?.trim() ?? '',
        'logoUrl': profile.logoUrl?.trim() ?? '',
      },
    );

    await _publicConfig(
      normalizedOwnerUid,
    ).set(sanitizeVanFirestoreMap(payload), SetOptions(merge: true));
  }
}
