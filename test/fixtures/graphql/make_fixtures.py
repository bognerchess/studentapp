#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Bogner Chess
# Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.
"""Writes the GraphQL response fixtures next to this file.

    python3 test/fixtures/graphql/make_fixtures.py

One directory per operation of graphql/operations/, one JSON file per scenario,
each the body of a GraphQL response. The files are committed; this script only
keeps the many near-identical error fixtures consistent. After a run:
`flutter test test/core/api test/tool`. See README.md.
"""
import json
import os

root = os.path.dirname(os.path.abspath(__file__))

def write(op, scenario, data=None, body=None):
    d = os.path.join(root, op)
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, scenario + '.json'), 'w') as f:
        json.dump(body if body is not None else {'data': data}, f, indent=2, ensure_ascii=False)
        f.write('\n')

def game(id, **kw):
    g = {'id': id, 'clientGameId': None, 'playerColor': 'WHITE', 'result': 'WHITE_WINS', 'resultText': '1-0',
         'playedDate': '2026-09-12', 'eventName': 'Club Championship', 'timeControl': '5400+30',
         'opponentName': 'Jonas Keller', 'whitePlayerName': 'Fake User', 'blackPlayerName': 'Jonas Keller',
         'whiteElo': 1650, 'blackElo': 1712, 'created': '2026-09-12T18:30:00.000Z',
         'hasAnalysis': False}
    g.update(kw)
    return g

G1 = game('game-1', clientGameId='3f0e1c52-7b1d-4a53-9c55-0d8a1b2c3d41', hasAnalysis=True)
G2 = game('game-2', clientGameId='8a6de0a4-2c0f-4f0e-8a44-6f3a5e7d9b12', playerColor='BLACK', result='DRAW', resultText='1/2-1/2',
          playedDate='2026-09-05', eventName='Rapid Open Zürich', timeControl='900+10', opponentName='Mira Østergård',
          whitePlayerName='Mira Østergård', blackPlayerName='Fake User', whiteElo=1820, blackElo=1650,
          created='2026-09-05T20:05:00.000Z')
G3 = game('game-3', clientGameId=None, result='BLACK_WINS', resultText='0-1', playedDate=None, eventName=None,
          timeControl=None, opponentName='Anonymous', whitePlayerName=None, blackPlayerName='Anonymous',
          whiteElo=None, blackElo=None, created='2026-08-30T09:00:00.000Z')

# ---- queries
write('MobileConfig', 'default', {'mobileConfig': {
    'minSupportedAppVersion': '0.1.0', 'maxAnalysisSchemaVersion': 1, 'supportedCoachLanguages': ['en', 'de'],
    'jobPollIntervalSeconds': 3, 'featureFlags': [{'key': 'push', 'enabled': False}, {'key': 'eval_graph', 'enabled': True}],
    'currentAiConsentVersion': 1}})
write('MobileConfig', 'update_required', {'mobileConfig': {
    'minSupportedAppVersion': '9.0.0', 'maxAnalysisSchemaVersion': 2, 'supportedCoachLanguages': ['en'],
    'jobPollIntervalSeconds': 0, 'featureFlags': [], 'currentAiConsentVersion': 2}})

def conn(nodes, total, has_next, end):
    return {'myMobileGames': {'totalCount': total, 'pageInfo': {'hasNextPage': has_next, 'endCursor': end}, 'nodes': nodes}}
write('MyMobileGames', 'default', conn([G1, G2, G3], 3, False, 'c3'))
write('MyMobileGames', 'first_page', conn([G1, G2], 3, True, 'c2'))
write('MyMobileGames', 'last_page', conn([G3], 3, False, 'c3'))
write('MyMobileGames', 'empty', conn([], 0, False, None))
write('MyMobileGames', 'null_connection', {'myMobileGames': None})
write('MyMobileGames', 'unknown_enums', conn([
    game('game-9', playerColor='BOTH', result='ABANDONED', resultText='?',
         playedDate='not-a-date')], 1, False, 'c1'))

PGN = ('[Event "Club Championship"]\n[Site "?"]\n[Date "2026.09.12"]\n[Round "?"]\n[White "Fake User"]\n'
       '[Black "Jonas Keller"]\n[Result "1-0"]\n[WhiteElo "1650"]\n[BlackElo "1712"]\n[TimeControl "5400+30"]\n\n'
       '1. e4 e5 2. Nf3 Nc6 3. Bc4 Nf6 4. Ng5 d5 5. exd5 Nxd5 6. Nxf7 Kxf7 7. Qf3+ Ke6 8. Nc3 1-0\n')
detail = dict(G1, rawPgn=PGN, startingFen=None, site=None, round=None)
write('GameById', 'default', {'myChessGameById': detail})
write('GameById', 'not_found', {'myChessGameById': None})
write('GameById', 'unreadable_pgn', {'myChessGameById': dict(G3, rawPgn='1. e4 e5 2. Ke3 ???', startingFen=None, site=' ', round=None)})

def analysis(doc, feedback=None, version=1, minor=0):
    return {'gameAnalysis': {'id': 'analysis-1', 'chessGameId': 'game-1', 'schemaVersion': version, 'schemaMinor': minor,
            'createdAt': '2026-09-19T09:20:07.000Z', 'document': {'$fixture': doc}, 'commentFeedback': feedback or []}}
write('GameAnalysis', 'default', analysis('analysis/v1/forty-move-game.json', [
    {'id': 'feedback-1', 'commentId': '322b7d97-32b5-4bc3-9f81-475368d0ef1c', 'rating': 'UP'},
    {'id': 'feedback-2', 'commentId': '0e60df92-f823-4d99-a5e3-82cbad3c3ba1', 'rating': 'DOWN'},
    {'id': 'feedback-3', 'commentId': '7387da67-d9d2-4f5d-b152-56ba6d80d558', 'rating': 'SIDEWAYS'}]))
write('GameAnalysis', 'short_game', analysis('analysis/v1/short-game.json'))
write('GameAnalysis', 'fallback_case', analysis('analysis/v1/fallback-case.json'))
write('GameAnalysis', 'with_unknowns', analysis('analysis/forward-compat/v1-with-unknowns.json', minor=7))
write('GameAnalysis', 'newer_major', analysis('analysis/forward-compat/v2-major.json', version=2))
write('GameAnalysis', 'none', {'gameAnalysis': None})
g = analysis('x')
g['gameAnalysis']['document'] = {'schema': 'something-else'}
write('GameAnalysis', 'invalid_document', g)

def usage(**kw):
    u = {'policy': 'DEFAULT', 'dailyLimit': 3, 'dailyUsed': 1, 'dailyResetAt': '2026-09-19T22:00:00.000Z',
         'monthlyLimit': 30, 'monthlyUsed': 12, 'monthlyResetAt': '2026-09-30T22:00:00.000Z', 'queuedJobs': 1, 'maxQueuedJobs': 2}
    u.update(kw)
    return {'myAnalysisUsage': u}
write('MyAnalysisUsage', 'default', usage())
write('MyAnalysisUsage', 'limit_reached', usage(dailyUsed=3))
write('MyAnalysisUsage', 'unlimited', usage(policy='UNLIMITED', dailyLimit=None, monthlyLimit=None, queuedJobs=0))
write('MyAnalysisUsage', 'unknown_policy', usage(policy='TRIAL', dailyResetAt='2026-09-20T00:00:00+02:00'))

DOCS = {
 'AI_CONSENT': ('AI analysis of your games', 'KI-Analyse deiner Partien',
   'When you ask for an analysis, the moves of your game and the player names are sent to our analysis service. A language model writes the coach comments. **No account data is sent to the model provider.**\n\nYou can withdraw this consent at any time in the settings.',
   'Wenn du eine Analyse anforderst, werden die Züge deiner Partie und die Spielernamen an unseren Analysedienst gesendet. Ein Sprachmodell schreibt die Trainerkommentare. **Es werden keine Kontodaten an den Modellanbieter gesendet.**\n\nDu kannst diese Einwilligung jederzeit in den Einstellungen widerrufen.', 'Example AI Provider'),
 'PRIVACY_POLICY': ('Privacy policy', 'Datenschutzerklärung', '# Privacy policy\n\nPlaceholder text of the mock server.', '# Datenschutzerklärung\n\nPlatzhaltertext des Mock-Servers.', None),
 'TERMS': ('Terms of use', 'Nutzungsbedingungen', '# Terms of use\n\nPlaceholder text of the mock server.', '# Nutzungsbedingungen\n\nPlatzhaltertext des Mock-Servers.', None),
 'ANALYTICS_CONSENT': ('Help us improve the app', 'Hilf uns, die App zu verbessern', 'We would like to count how the app is used: which screens are opened and whether an analysis was requested. No game content, no names.', 'Wir möchten zählen, wie die App genutzt wird: welche Ansichten geöffnet werden und ob eine Analyse angefordert wurde. Keine Partieinhalte, keine Namen.', None),
}
for key, (ten, tde, ben, bde, provider) in DOCS.items():
    for lang, title, body in (('en', ten, ben), ('de', tde, bde)):
        write('LegalDocument', f'{key.lower()}_{lang}', {'legalDocument': {
            'id': f'legal-{key.lower()}-{lang}-1', 'key': key, 'version': 1, 'language': lang, 'title': title,
            'bodyMarkdown': body, 'providerName': provider, 'publishedAt': '2026-09-01T00:00:00.000Z', 'isDraft': True}})
write('LegalDocument', 'default', {'legalDocument': {
    'id': 'legal-ai_consent-en-1', 'key': 'AI_CONSENT', 'version': 1, 'language': 'en', 'title': DOCS['AI_CONSENT'][0],
    'bodyMarkdown': DOCS['AI_CONSENT'][2], 'providerName': DOCS['AI_CONSENT'][4], 'publishedAt': '2026-09-01T00:00:00.000Z', 'isDraft': True}})
write('LegalDocument', 'not_found', {'legalDocument': None})
write('LegalDocument', 'unknown_key', {'legalDocument': {
    'id': 'legal-x', 'key': 'COOKIE_POLICY', 'version': 3, 'language': 'en', 'title': 'Cookies', 'bodyMarkdown': 'x',
    'providerName': None, 'publishedAt': '2026-09-01T00:00:00.000Z', 'isDraft': False}})

def ai(accepted, required, current=1):
    return {'currentVersion': current, 'acceptedVersion': accepted, 'required': required}
def consent(key, accepted, required, withdrawn=None, current=1):
    return {'key': key, 'currentVersion': current, 'acceptedVersion': accepted, 'required': required, 'withdrawnAt': withdrawn}
write('MyAiConsent', 'required', {'myAiConsent': ai(None, True)})
write('MyAiConsent', 'default', {'myAiConsent': ai(1, False)})
write('MyAiConsent', 'new_version', {'myAiConsent': ai(1, True, current=2)})
write('MyConsent', 'required', {'myConsent': consent('ANALYTICS_CONSENT', None, True)})
write('MyConsent', 'default', {'myConsent': consent('ANALYTICS_CONSENT', 1, False)})
write('MyConsent', 'withdrawn', {'myConsent': consent('ANALYTICS_CONSENT', None, True, '2026-09-18T08:00:00.000Z')})

# ---- mutations
GENERIC = {
  'business_error': {'__typename': 'BusinessError', 'message': 'web_api_errors.entity_not_found'},
  'input_invalid': {'__typename': 'InputValidationError', 'message': 'web_api_errors.invalid_input', 'propertyName': 'Input'},
  'technical_error': {'__typename': 'TechnicalError', 'message': 'web_api_errors.technical_error'},
  'unknown_error': {'__typename': 'SomethingNewError'},
}
RATE = {'__typename': 'RateLimitedError', 'message': 'web_api_errors.rate_limited', 'retryAfterSeconds': 42}

def mutation(op, field, entity, ok, errors, generic_overrides=None):
    for scenario, value in ok.items():
        write(op, scenario, {field: {entity: value, 'errors': None}})
    all_errors = dict(GENERIC)
    all_errors.update(generic_overrides or {})
    all_errors.update(errors)
    for scenario, error in all_errors.items():
        write(op, scenario, {field: {entity: None, 'errors': [error]}})

imported = game('game-10', clientGameId='11111111-2222-4333-8444-555555555555', created='2026-09-19T10:00:00.000Z',
                playedDate='2026-09-19')
mutation('ImportMobileGame', 'importMobileGame', 'chessGame', {'default': imported}, {
    'pgn_invalid': {'__typename': 'PgnInvalidError', 'message': 'web_api_errors.pgn_invalid', 'moveNumber': 7, 'san': 'Qxf9'},
    'pgn_invalid_without_move': {'__typename': 'PgnInvalidError', 'message': 'web_api_errors.pgn_invalid', 'moveNumber': None, 'san': None},
    'rate_limited': RATE},
    {'input_invalid': {'__typename': 'InputValidationError', 'message': 'web_api_errors.pgn_too_long', 'propertyName': 'Pgn'}})
write('ImportMobileGame', 'empty_payload', {'importMobileGame': {'chessGame': None, 'errors': None}})
mutation('DeleteChessGame', 'deleteChessGame', 'chessGame', {'default': {'id': 'game-1'}}, {})
mutation('SubmitCoachCommentFeedback', 'submitCoachCommentFeedback', 'coachCommentFeedback', {
    'default': {'id': 'feedback-1', 'commentId': '322b7d97-32b5-4bc3-9f81-475368d0ef1c', 'rating': 'UP'},
    'down': {'id': 'feedback-1', 'commentId': '322b7d97-32b5-4bc3-9f81-475368d0ef1c', 'rating': 'DOWN'},
    'cleared': None}, {},
    {'business_error': {'__typename': 'BusinessError', 'message': 'web_api_errors.comment_not_found'}})
device = {'id': 'device-1', 'deviceId': 'installation-1', 'environment': 'SANDBOX', 'appVersion': '0.1.0+1', 'locale': 'de-CH',
          'lastSeenAt': '2026-09-19T10:00:00.000Z', 'revokedAt': None}
mutation('RegisterMobileDevice', 'registerMobileDevice', 'mobileDevice', {'default': device}, {'rate_limited': RATE})
mutation('UnregisterMobileDevice', 'unregisterMobileDevice', 'mobileDevice', {
    'default': dict(device, revokedAt='2026-09-19T11:00:00.000Z'), 'unknown_device': None}, {})
mutation('TrackMobileEvents', 'trackMobileEvents', 'eventBatch', {
    'default': {'accepted': 3, 'rejected': 0}, 'partially_rejected': {'accepted': 2, 'rejected': 1}}, {'rate_limited': RATE},
    {'input_invalid': {'__typename': 'InputValidationError', 'message': 'web_api_errors.invalid_input', 'propertyName': 'Events'}})
mutation('RecordAiConsent', 'recordAiConsent', 'aiConsentStatus', {'default': ai(1, False)}, {},
    {'input_invalid': {'__typename': 'InputValidationError', 'message': 'web_api_errors.invalid_input', 'propertyName': 'Version'}})
mutation('RecordConsent', 'recordConsent', 'consentStatus', {
    'default': consent('ANALYTICS_CONSENT', 1, False),
    'withdrawn': consent('ANALYTICS_CONSENT', None, True, '2026-09-19T10:00:00.000Z')}, {},
    {'input_invalid': {'__typename': 'InputValidationError', 'message': 'web_api_errors.invalid_input', 'propertyName': 'Version'}})
mutation('DeleteMyAccount', 'deleteMyAccount', 'accountDeletion', {
    'default': {'id': 'deletion-1', 'status': 'PENDING', 'requestedAt': '2026-09-19T10:00:00.000Z', 'completedAt': None},
    'completed': {'id': 'deletion-1', 'status': 'COMPLETED', 'requestedAt': '2026-09-19T10:00:00.000Z', 'completedAt': '2026-09-19T10:00:02.000Z'},
    'unknown_status': {'id': 'deletion-1', 'status': 'ARCHIVED', 'requestedAt': '2026-09-19T10:00:00.000Z', 'completedAt': None}}, {
    'blocked': {'__typename': 'AccountDeletionBlockedError', 'message': 'web_api_errors.account_deletion_blocked', 'reason': 'owns_club'}},
    {'input_invalid': {'__typename': 'InputValidationError', 'message': 'web_api_errors.account_deletion_confirmation_mismatch', 'propertyName': 'Confirmation'}})

# ---- the staged pipeline (WP-60)
#
# The workflow query is what the tracker polls; it carries no artifact. The
# states below are derived the way the backend derives them, so a scenario
# cannot say something the server could never send: a stage is runnable when
# every earlier stage is ready and nothing is in flight, and `blockedBy` names
# the nearest earlier stage that is not ready.
STAGES = ['BASE_EVALUATION', 'BASE_CLASSIFICATION', 'DEEP_EVALUATION', 'COACHING']

def stage_run(id, status, done=None, total=None, step=None, finished=None, failure=None,
              persona=None, language=None, requested='2026-09-19T10:00:00.000Z', started=None,
              has_artifact=None):
    return {'id': id, 'status': status,
            'hasArtifact': has_artifact if has_artifact is not None else status == 'DONE',
            'progressStage': step, 'progressDone': done, 'progressTotal': total,
            'persona': persona, 'language': language, 'requestedAt': requested,
            'startedAt': started, 'finishedAt': finished,
            'failureCode': failure, 'failureMessage': None if failure is None else 'stage failed'}

def workflow(states, runs=None, game='game-1'):
    """A GameAnalysisWorkflow from one state per stage; everything else follows."""
    runs = runs or {}
    stages = []
    for index, name in enumerate(STAGES):
        state = states[index]
        earlier = [STAGES[i] for i in range(index) if states[i] != 'READY']
        active = any(s in ('QUEUED', 'RUNNING') for s in states)
        stages.append({
            'stage': name, 'state': state,
            'runnable': not earlier and not active and state != 'READY',
            'blockedBy': earlier[-1] if earlier else None,
            'usesModel': name == 'COACHING',
            'run': runs.get(name),
        })
    nxt = next((s['stage'] for s in stages if s['runnable']), None)
    return {'gameAnalysisWorkflow': {
        'chessGameId': game, 'stages': stages, 'nextRunnableStage': nxt,
        'isComplete': all(s == 'READY' for s in states)}}

READY_RUNS = {
    'BASE_EVALUATION': stage_run('run-be', 'DONE', finished='2026-09-19T10:01:00.000Z'),
    'BASE_CLASSIFICATION': stage_run('run-bc', 'DONE', finished='2026-09-19T10:01:20.000Z'),
    'DEEP_EVALUATION': stage_run('run-de', 'DONE', finished='2026-09-19T10:03:00.000Z'),
    'COACHING': stage_run('run-co', 'DONE', finished='2026-09-19T10:04:30.000Z',
                          persona='house', language='en'),
}

write('GameAnalysisWorkflow', 'default', workflow(
    ['RUNNING', 'NOT_RUN', 'NOT_RUN', 'NOT_RUN'],
    {'BASE_EVALUATION': stage_run('run-be', 'RUNNING', done=8, total=21, step='scan',
                                  started='2026-09-19T10:00:05.000Z')}))
write('GameAnalysisWorkflow', 'not_run', workflow(['NOT_RUN'] * 4))
write('GameAnalysisWorkflow', 'running', workflow(
    ['READY', 'RUNNING', 'NOT_RUN', 'NOT_RUN'],
    {'BASE_EVALUATION': READY_RUNS['BASE_EVALUATION'],
     'BASE_CLASSIFICATION': stage_run('run-bc', 'RUNNING', started='2026-09-19T10:01:05.000Z')}))
write('GameAnalysisWorkflow', 'engine_ready', workflow(
    ['READY', 'READY', 'READY', 'NOT_RUN'],
    {k: v for k, v in READY_RUNS.items() if k != 'COACHING'}))
write('GameAnalysisWorkflow', 'all_ready', workflow(['READY'] * 4, READY_RUNS))
write('GameAnalysisWorkflow', 'stage_failed', workflow(
    ['READY', 'READY', 'FAILED', 'NOT_RUN'],
    {'BASE_EVALUATION': READY_RUNS['BASE_EVALUATION'],
     'BASE_CLASSIFICATION': READY_RUNS['BASE_CLASSIFICATION'],
     'DEEP_EVALUATION': stage_run('run-de', 'FAILED', finished='2026-09-19T10:02:40.000Z',
                                  failure='stage_input_missing', has_artifact=False)}))
write('GameAnalysisWorkflow', 'stale', workflow(
    ['STALE', 'STALE', 'STALE', 'STALE'], READY_RUNS))
# A stage and a state of the future: both have to read as "unknown" and leave
# the pipeline alone.
unknown = workflow(['READY', 'PAUSED', 'NOT_RUN', 'NOT_RUN'],
                   {'BASE_EVALUATION': READY_RUNS['BASE_EVALUATION']})
unknown['gameAnalysisWorkflow']['stages'][1]['stage'] = 'SHINY_NEW_STAGE'
unknown['gameAnalysisWorkflow']['nextRunnableStage'] = 'SHINY_NEW_STAGE'
write('GameAnalysisWorkflow', 'unknown_stage', unknown)
# The game is gone or is somebody else's: the field is non-null in the schema,
# so the server can only answer with a top-level error.
write('GameAnalysisWorkflow', 'not_found', body={
    'errors': [{'message': 'The game does not exist.',
                'path': ['gameAnalysisWorkflow']}]})

# Artifacts, kept small on purpose: one fetch of a real one is hundreds of
# kilobytes, and these files are read by every fixture test. The nodes are the
# first plies of the vendored short game, which is where the shapes come from.
SHORT = json.load(open(os.path.join(root, '..', 'analysis', 'v1', 'short-game.json')))

def scan_positions(count):
    return [{'fen': SHORT['nodes'][i]['fen_before'],
             'eval_white': SHORT['nodes'][i]['eval_before'],
             'best': None, 'terminal': False} for i in range(count)]

def base_artifact(count=3):
    return {
        'artifact_version': 1, 'stage': 'base_evaluation', 'student_color': 'black',
        'white_rating': 1180, 'black_rating': 1100,
        'scan': {'game': {'moves_san': [n['san'] for n in SHORT['nodes'][:count]],
                          'moves_uci': [n['uci'] for n in SHORT['nodes'][:count]],
                          'start_fen': None, 'result': SHORT['game']['result']},
                 'positions': scan_positions(count), 'book': [True] * count,
                 'opening_name': 'Caro-Kann Defence', 'engine_calls': count},
        'nodes': [dict(n, is_critical=False, variations=[], comment_ids=[])
                  for n in SHORT['nodes'][:count]],
        'human': {'predictions': {}, 'peer_gap': {}, 'available': False},
        'engine_calls': count,
    }

def classification_artifact():
    return {'artifact_version': 1, 'stage': 'base_classification',
            'selections': [{'ply': 10, 'kind': 'critical_moment', 'score': 9.7, 'reason': 'mistake'},
                           {'ply': 16, 'kind': 'critical_moment', 'score': 26.4, 'reason': 'blunder'}],
            'sharpness': {}}

def deep_artifact(count=3):
    return {
        'artifact_version': 1, 'stage': 'deep_evaluation',
        'context': {'language': 'en', 'student_color': 'black', 'rating_band': '1000-1200',
                    'result': SHORT['game']['result'], 'ply_count': SHORT['game']['ply_count'],
                    'opening_name': 'Caro-Kann Defence'},
        'nodes': SHORT['nodes'][:count],
        'moments': [{'ply': 10, 'kind': 'critical_moment', 'phase': 'opening',
                     'moves_before_san': [], 'motifs': [], 'material_balance': 0,
                     'peer_move_san': None, 'peer_move_prob': None, 'selection_score': 9.7}],
        'dropped': [], 'accuracy': SHORT['accuracy'],
        # Flat, not nested: this is the shape StageDocumentAssembler reshapes.
        'engine': {'name': SHORT['engine']['name'], 'pass1_nodes': 400000,
                   'pass2_nodes': 3000000, 'pass2_multipv': 3, 'human_model': 'maia3-5m'},
        'engine_calls': 12,
    }

def run(id, stage, status='DONE', artifact=None, game='game-1', superseded=None,
        finished='2026-09-19T10:01:00.000Z', failure=None):
    return {'engineStageRun': {
        'id': id, 'chessGameId': game, 'stage': stage, 'status': status, 'artifact': artifact,
        'supersededAt': superseded, 'finishedAt': finished, 'failureCode': failure,
        'failureMessage': None if failure is None else 'stage failed'}}

write('EngineStageRun', 'default', run('run-be', 'BASE_EVALUATION', artifact=base_artifact()))
write('EngineStageRun', 'base_classification',
      run('run-bc', 'BASE_CLASSIFICATION', artifact=classification_artifact()))
write('EngineStageRun', 'deep_evaluation',
      run('run-de', 'DEEP_EVALUATION', artifact=deep_artifact()))
write('EngineStageRun', 'coaching', run('run-co', 'COACHING', artifact={
    'artifact_version': 1, 'stage': 'coaching',
    'document': {'$fixture': 'analysis/v1/short-game.json'},
    'coach': {'provider': 'azure', 'model': 'gpt-4.1'},
    'llm': {'calls': 4, 'tokens_in': 8200, 'tokens_out': 1400, 'cost_usd_est': 0.021,
            'regenerations': 0, 'fallbacks': 0},
    'engine_calls': 0}))
write('EngineStageRun', 'superseded',
      run('run-be-old', 'BASE_EVALUATION', artifact=base_artifact(),
          superseded='2026-09-19T11:00:00.000Z'))
write('EngineStageRun', 'running',
      run('run-de', 'DEEP_EVALUATION', status='RUNNING', finished=None))
write('EngineStageRun', 'failed',
      run('run-de', 'DEEP_EVALUATION', status='FAILED', failure='stage_input_missing'))
write('EngineStageRun', 'unknown_stage', run('run-x', 'SHINY_NEW_STAGE', status='PAUSED'))
write('EngineStageRun', 'not_found', {'engineStageRun': None})

# The three engine commands. `prerequisite_missing` is the one BusinessError
# the app reads as an outcome of its own; every other one is a plain failure.
PREREQUISITE = {'__typename': 'BusinessError',
                'message': 'web_api_errors.stage_prerequisite_missing'}
STAGE_ERRORS = {'prerequisite_missing': PREREQUISITE, 'rate_limited': RATE}
STAGE_GENERIC = {'business_error': {'__typename': 'BusinessError',
                                    'message': 'api_errors.entity_not_found'},
                 'input_invalid': {'__typename': 'InputValidationError',
                                   'message': 'web_api_errors.invalid_input',
                                   'propertyName': 'ChessGameId'}}
for op, field, stage in (('RunBaseEvaluation', 'runBaseEvaluation', 'BASE_EVALUATION'),
                         ('RunBaseClassification', 'runBaseClassification', 'BASE_CLASSIFICATION'),
                         ('RunDeepEvaluation', 'runDeepEvaluation', 'DEEP_EVALUATION')):
    mutation(op, field, 'engineStageRun',
             {'default': run('run-new', stage, status='QUEUED', finished=None)['engineStageRun']},
             STAGE_ERRORS, STAGE_GENERIC)

# Coaching is the metered stage, so it answers with the whole set the
# whole-game request used to.
mutation('RunCoaching', 'runCoaching', 'engineStageRun',
         {'default': run('run-new', 'COACHING', status='QUEUED', finished=None)['engineStageRun']},
         {'limit_reached': {'__typename': 'AnalysisLimitReachedError',
                            'message': 'web_api_errors.analysis_limit_reached',
                            'window': 'DAY', 'limit': 3, 'used': 3,
                            'resetAt': '2026-09-19T22:00:00.000Z'},
          'limit_reached_month': {'__typename': 'AnalysisLimitReachedError',
                                  'message': 'web_api_errors.analysis_limit_reached',
                                  'window': 'MONTH', 'limit': 30, 'used': 30,
                                  'resetAt': '2026-09-30T22:00:00.000Z'},
          'limit_reached_unknown_window': {'__typename': 'AnalysisLimitReachedError',
                                           'message': 'web_api_errors.analysis_limit_reached',
                                           'window': 'WEEK', 'limit': 10, 'used': 10,
                                           'resetAt': '2026-09-21T00:00:00+02:00'},
          'queue_full': {'__typename': 'AnalysisQueueFullError',
                         'message': 'web_api_errors.analysis_queue_full', 'maxQueuedJobs': 2},
          'rate_limited': RATE,
          'email_not_verified': {'__typename': 'EmailNotVerifiedError',
                                 'message': 'web_api_errors.email_not_verified'},
          'ai_consent_required': {'__typename': 'AiConsentRequiredError',
                                  'message': 'web_api_errors.ai_consent_required',
                                  'requiredVersion': 1},
          'prerequisite_missing': PREREQUISITE},
         STAGE_GENERIC)
