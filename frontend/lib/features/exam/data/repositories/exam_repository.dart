import 'package:internhub_app/core/constants/api_constants.dart';
import 'package:internhub_app/core/network/dio_client.dart';
import 'package:internhub_app/features/exam/domain/entities/exam_entities.dart';

class ExamRepository {
  final DioClient _client;
  ExamRepository(this._client);

  Future<ExamSessionInfo> startSession(String internshipId) async {
    final resp = await _client.dio.post(
      ApiConstants.examSessions,
      data: {'internship_id': internshipId},
    );
    return ExamSessionInfo.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<ExamSessionInfo> getSession(String sessionId) async {
    final resp =
        await _client.dio.get(ApiConstants.examSessionDetail(sessionId));
    return ExamSessionInfo.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<List<ExamQuestion>> getSessionQuestions(String sessionId) async {
    final resp = await _client.dio
        .get('${ApiConstants.examSessionDetail(sessionId)}/questions');
    final list = resp.data as List<dynamic>;
    return list.map((q) => ExamQuestion.fromJson(q)).toList();
  }

  Future<void> submitAnswer({
    required String sessionId,
    required String questionId,
    int? selectedOptionIndex,
    String? answerText,
    int? timeSpentSeconds,
  }) async {
    await _client.dio.post(
      '${ApiConstants.examSessionDetail(sessionId)}/answers',
      data: {
        'question_id': questionId,
        if (selectedOptionIndex != null)
          'selected_option_index': selectedOptionIndex,
        if (answerText != null) 'answer_text': answerText,
        if (timeSpentSeconds != null) 'time_spent_seconds': timeSpentSeconds,
      },
    );
  }

  Future<ExamSessionInfo> submitSession(String sessionId) async {
    final resp = await _client.dio.post(ApiConstants.submitExam(sessionId));
    return ExamSessionInfo.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> logProctorEvent({
    required String sessionId,
    required String eventType,
    int severity = 1,
    String? screenshotUrl,
    Map<String, dynamic>? metadata,
  }) async {
    await _client.dio.post(
      ApiConstants.proctorEvents(sessionId),
      data: {
        'session_id': sessionId,
        'event_type': eventType,
        'severity': severity,
        if (screenshotUrl != null) 'screenshot_url': screenshotUrl,
        if (metadata != null) 'metadata': metadata,
      },
    );
  }
}
