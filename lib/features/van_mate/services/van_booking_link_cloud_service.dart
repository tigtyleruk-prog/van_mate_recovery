import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/van_business_profile.dart';
import '../models/van_custom_job_question.dart';
import '../models/van_job_service.dart';
import '../models/van_prefilled_job_questions.dart';
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
    required String title,
    required bool isActive,
    required VanBusinessProfile profile,
    required List<VanJobService> activeServices,
    required Map<String, VanCustomJobQuestion> questionLookup,
    String source = 'van_mate.booking_link_publish',
  }) async {
    final normalizedOwnerUid = ownerUid.trim();
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
      id: normalizedOwnerUid,
      ownerUid: normalizedOwnerUid,
      source: source,
      createdAt: now,
      updatedAt: now,
      data: <String, dynamic>{
        'title': title.trim(),
        'isActive': isActive,
        'businessName': normalizedBusinessName,
        'contactName': profile.contactName.trim(),
        'phone': profile.phone.trim(),
        'email': profile.email.trim(),
        'logoPath': profile.logoPath?.trim() ?? '',
        'logoUrl': profile.logoUrl?.trim() ?? '',
        'introText':
            "Choose a service and tell us what you need. We'll get back to you with a quote.",
        'services': activeServices
            .map(
              (service) => <String, dynamic>{
                'id': service.id,
                'name': service.name.trim(),
                'description': service.description.trim(),
                'requireAddress': service.requireAddress,
                'requestPhotos': service.requestPhotos,
                'requestExactPinAfterQuoteAccepted':
                    service.requestExactPinAfterQuoteAccepted,
                'linkedQuestions': service.linkedQuestionIds
                    .map((id) => questionLookup[id])
                    .whereType<VanCustomJobQuestion>()
                    .where(
                      (question) => question.isActive && !question.isArchived,
                    )
                    .where(
                      (question) =>
                          !VanPrefilledJobQuestions
                              .isDeprecatedDuplicatePresetId(
                            question.id,
                          ),
                    )
                    .map(
                      (question) => <String, dynamic>{
                        'id': question.id,
                        'questionText': question.questionText.trim(),
                        'helperText': question.helperText.trim(),
                        'answerType': question.answerType.storageKey,
                        'category': question.category?.storageKey ?? '',
                        'choiceOptions': question.choiceOptions,
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
      docId: normalizedOwnerUid,
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
        normalizedOwnerUid,
      ).set(sanitizeVanFirestoreMap(payload), SetOptions(merge: true));
      logVanFirebaseWriteSuccess(
        collectionPath: 'public_booking_links',
        docId: normalizedOwnerUid,
        uid: normalizedOwnerUid,
        source: source,
      );
    } catch (error) {
      logVanFirebaseWriteFailure(
        collectionPath: 'public_booking_links',
        docId: normalizedOwnerUid,
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
