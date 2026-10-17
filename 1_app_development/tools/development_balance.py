"""개발 임시 수치 원장 검증 및 문서 생성. 앱 실행·경제 시뮬레이션 도구가 아니다."""
import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / '1_app_development/config/development_balance.json'
DOC = ROOT / '2_development_plans_and_checklists/2.1_development_specs_tasks_and_progress/14_개발용임시수치설정.md'
SERVER_CONFIG = ROOT / '1_app_development/firebase/functions/src/generated/development_balance.json'
CATALOG = ROOT / '1_app_development/firebase/functions/src/catalog.json'


def require(ok, message):
    if not ok:
        raise ValueError(message)


def validate(data, catalog):
    def walk(value, path=''):
        require(value is not None, f'{path}: 빈 값 금지')
        if isinstance(value, dict):
            for key, child in value.items():
                walk(child, f'{path}.{key}')
        elif isinstance(value, list):
            require(bool(value), f'{path}: 빈 목록 금지')
            for index, child in enumerate(value):
                walk(child, f'{path}[{index}]')
        elif isinstance(value, (float, int)) and not isinstance(value, bool):
            require(isinstance(value, int) and value >= 0, f'{path}: 음수/부동소수점 금지')
        elif isinstance(value, str):
            require(bool(value.strip()), f'{path}: 빈 문자열 금지')
    walk(data)
    require(data['metadata']['schema_version'] == 1, '수치 스키마 버전')
    fixed = {'max_level': 50, 'griddle_slots': 6, 'doneness_stages': 5,
             'mastery_discoveries_required': 5, 'inventory_expiry_business_days': 5,
             'offline_cap_ms': 28800000, 'offline_efficiency_permille': 500,
             'rewarded_ads_per_account_day': 2, 'ad_timezone_offset_minutes': 540,
             'pause_customer_timer_during_ad': True,
             'pause_manual_cooking_timer_during_ad': True,
             'pause_griddle_timer_during_ad': True}
    require(data['fixed_requirements'] == fixed and
            all(type(data['fixed_requirements'][k]) is type(v) for k, v in fixed.items()),
            '확정 요구 변경: 별도 승인/계약 변경 필요')
    require(data['metadata']['runtime_connected'] is False and
            data['metadata']['release_validated'] is False, '미연동/미검증 상태를 숨기지 말 것')
    require(data['initial_state']['gold'] == 0 and
            data['initial_state']['starting_real_inventory'] == 0 and
            data['initial_state']['mastery_complete'] is False and
            data['initial_state']['recipe_flavor'] == 'redbean' and
            data['initial_state']['recipe_variant'] == 'medium', '초기 레시피/자산 계약 불일치')
    relationship = data['customer_relationships']
    thresholds = relationship['stage_thresholds']
    require(relationship['provisional'] is True and len(thresholds) == 4 and thresholds[0] == 0
            and all(a < b for a, b in zip(thresholds, thresholds[1:]))
            and thresholds[-1] <= relationship['affinity_cap'], '손님 관계 단계/상한 오류')
    require(relationship['choice_chance_basis_points'] <= 10000 and
            relationship['delay_threshold_permille'] <= 1000, '손님 관계 비율 범위 오류')
    for key in ('affinity_cap', 'ordinary_daily_cap', 'choice_daily_cap', 'recent_dialogue_limit',
                'return_gap_business_days', 'new_npcs_daily_limit', 'visits_per_npc_business_day',
                'choice_first_business_day', 'choice_gap_business_days', 'choice_skip_retry_business_days'):
        require(relationship[key] > 0, f'손님 관계 양수 설정: {key}')
    for key in ('sale_affinity', 'corrected_sale_affinity', 'automatic_dialogue_affinity'):
        require(relationship[key] <= relationship['ordinary_daily_cap'], f'손님 관계 일반 상한: {key}')
    points = relationship['choice_affinity']
    require(set(points) == {'a', 'b', 'c', 'wave'} and points['wave'] == 0 and
            relationship['choice_daily_cap'] >= points['a'] > points['b'] > points['c'] >= 0,
            '손님 선택 점수/상한 오류')
    npc_ids = {'npc_' + name for name in ('yunha','doyun','makrye','seojin','taeo','eunchae','minjae','sua')}
    for section in ('customer_choice_conditions','customer_story_conditions','customer_order_preferences'):
        require(set(data[section]) == npc_ids, f'손님 조건 목록 불일치: {section}')
    for npc_id in npc_ids:
        choice = data['customer_choice_conditions'][npc_id]
        require(isinstance(choice['min_affinity'],int) and isinstance(choice['min_visits'],int), '손님 선택 최소 조건 오류')
        require(0 <= data['customer_story_conditions'][npc_id]['stage'] < len(thresholds), '손님 관계 단계 오류')
        preference = data['customer_order_preferences'][npc_id]
        require(preference['flavor'] in data['active_recipes'] and preference['quantity'] > 0, '손님 주문 성향 오류')
    require(relationship['new_npcs_daily_limit'] == 2, '확정 신규 손님 일일 소개 한도 변경')
    require(relationship['anonymous_visit_basis_points'] <= 10000 and relationship['holiday_visit_basis_points'] <= 10000 and relationship['own_portion_extra_quantity'] > 0, '손님 방문 비율/수량 오류')
    entries = data['skill_purchase']['entries']
    require(set(entries) == {f'{kind}_{i}' for kind in ('tap', 'auto') for i in range(1, 17)},
            '기존 32개 스킬 누락/가상 ID 추가')
    require(set(data['cosmetic_purchase']) == set(catalog['spend']['cosmetic']), '꾸미기 가격 누락')
    require(set(data['boost_purchase']) == set(catalog['spend']['boost']), '부스트 가격 누락')
    require(data['existing_iap_products'] == catalog['products'], '기존 IAP ID/수량 보존 위반')
    for group in (entries, data['cosmetic_purchase'], data['boost_purchase']):
        for key, price in group.items():
            require(isinstance(price['buns'], str) and re.fullmatch(r'[1-9][0-9]*', price['buns']),
                    f'{key}: 붕어빵력 비용은 양수 10진 문자열')
            require(type(price['gold']) is int and price['gold'] > 0, f'{key}: 황금 비용 필요')
    expected_goals = {'daily': {'taps', 'production', 'purchases', 'auto'}, 'weekly': {'taps', 'days', 'purchases', 'dailyAll'}}
    require(data['mission_gold_rewards']['daily_all'] > 0, '전체 일일 보상')
    for scope, expected in expected_goals.items():
        goals = data['mission_targets'][scope]
        require(set(goals) == expected, '사용자 확정 미션 구성')
        for key, row in goals.items():
            require(row['metric'] == key and re.fullmatch(r'[1-9][0-9]*', row['target']) and
                    data['mission_gold_rewards'][row['reward_key']] > 0, f'{scope}/{key}: 미션 목표/보상')
    avatar = data['avatar_catalog']
    avatar_slots = {'character', 'skin', 'hair', 'top', 'bottom', 'shoes', 'outfit', 'hat', 'accessory', 'tool'}
    require(bool(avatar), '아바타 카탈로그 누락')
    for key, row in avatar.items():
        require(row['slot'] in avatar_slots and type(row['free']) is bool and
                type(row['unlock_level']) is int and 1 <= row['unlock_level'] <= 50 and
                isinstance(row['unlock_total'], str) and re.fullmatch(r'0|[1-9][0-9]*', row['unlock_total']) and
                (row['free'] or key in data['cosmetic_purchase']), f'{key}: 아바타 보유/해금 카탈로그')
    for key, price in entries.items():
        require(isinstance(price['effect'], str) and re.fullmatch(r'[1-9][0-9]*', price['effect']) and
                isinstance(price['unlock_total'], str) and re.fullmatch(r'0|[1-9][0-9]*', price['unlock_total']),
                f'{key}: 스킬 효과/해금 누적은 유효한 BigInt 문자열')
        require(price['ratio_denominator'] > 0 and
                price['ratio_numerator'] >= price['ratio_denominator'], f'{key}: 가격 증가비')
    require(data['skill_purchase']['gold_step_purchase_count'] > 0, '황금 가격 회차 분모')
    for row in data['mastery_difficulties']:
        require(row['practice_required'] >= row['technique_passes_required'] > 0, '숙련량 관계')
        require(row['doneness_target_ms'] > 0 and row['batter_target_ms'] > 0, '시간 기준 양수')
        require(row['success_doneness_min_index'] == 1 and row['success_doneness_max_index'] == 3, '손기술 일반 판매 익힘')
    boundaries = data['doneness']['boundary_permille']
    require(len(boundaries) == 4 and all(a < b for a, b in zip([0] + boundaries, boundaries)),
            '익힘5단계 경계 중복/순서')
    require(data['doneness']['reference_scale'] == 1000, '익힘 천분율 단위')
    require(data['doneness']['reference_medium_stage_index'] == 2, '확정 미디엄 인덱스')
    require(len(data['griddle']['slot_speed_permille']) == 6 and
            all(v > 0 for v in data['griddle']['slot_speed_permille']), '6구 속도 누락')
    sale = data['ordinary_sale']
    require(len(sale['freshness_price_permille_by_age']) == 5, '재고 나이0~4 가격 누락')
    probs = data['rare_gold_sale']['probability_basis_points_by_stars']
    require(len(probs) == 5 and 0 < probs[0] and probs[-1] < 10000 and
            all(a < b for a, b in zip(probs, probs[1:])), '별점 확률 순서/확정 지급 금지')
    audio = data['audio']
    for key in ('bgm_default_percent', 'sfx_default_percent', 'cooking_default_percent'):
        require(type(audio[key]) is int and 0 <= audio[key] <= 100, '오디오 음량 범위')
    require(type(audio['cooking_enabled_by_default']) is bool, '굽기 기본 설정 형식')
    require(data['rewarded_ads']['gold_per_verified_view'] > 0, '광고 보상 누락')
    require(data['rewarded_ads']['provider_verification_window_ms'] >=
            data['rewarded_ads']['reservation_soft_timeout_ms'] > 0, '광고 검증/예약 시간 관계')
    rows = data['level_progression']
    require([v['level'] for v in rows] == list(range(1, 51)), '레벨1~50 누락/중복')
    totals = [int(v['season_total_buns']) for v in rows]
    require(all(a < b for a, b in zip(totals, totals[1:])), '누적 목표 단조 증가')
    for v in rows:
        require(v['order_wait_ms'] > 0 and v['max_queue'] > 0 and
                v['order_quantity_limit'] >= v['order_flavor_limit'] >= 1, '주문 임시 표 관계')
    recipes = data['active_recipes']
    require(set(recipes) == {'redbean', 'custard', 'cocoa'} and
            [key for key, value in recipes.items() if value['initial']] == ['redbean'], '초기/추가 맛 계약')
    require(all(0 <= row['difficulty'] <= 2 and type(row['initial']) is bool for row in recipes.values()), '맛 난이도 ID/초기 여부')
    require(data['ordinary_sale']['customer_archetype_count'] > 0, '손님 원형 개수')
    gesture = data['manual_cooking']
    require(all(isinstance(gesture.get(key), int) and not isinstance(gesture.get(key), bool) and gesture[key] > 0 for key in (
        'filling_swipe_min_distance_px', 'filling_swipe_max_duration_ms',
        'filling_swipe_dominance_permille', 'filling_rotation_degrees', 'filling_rotation_min_radius_px')), '속 넣기 제스처 설정')
    require(gesture['filling_swipe_dominance_permille'] >= 1000, '스와이프 주축 비율')
    require(data['manual_cooking']['checkpoint_ms'] > 0 and
            data['manual_cooking']['filling_inputs'] > 0 and
            data['manual_cooking']['tilt_sampling_ms'] > 0, '제작 입력/저장 간격')
    sale = data['ordinary_sale']
    require(sale['customer_arrival_interval_ms'] > 0 and
            0 <= sale['special_order_basis_points'] <= 10000 and
            0 <= sale['specific_variant_basis_points'] <= 10000, '방문/특별 주문 임시 수치')
    require(sale['quality_weight_permille'] + sale['freshness_weight_permille'] == 1000,
            '만족도 품질/신선도 가중치 합')
    for key in ('quality_permille_by_doneness', 'freshness_satisfaction_permille_by_age',
                'freshness_price_permille_by_age'):
        require(len(sale[key]) == 5 and all(0 <= x <= 1000 for x in sale[key]), '판매 계수 범위')
    thresholds = sale['satisfaction_threshold_permille']
    require(len(thresholds) == 5 and thresholds[0] == 0 and thresholds[-1] <= 1000 and
            all(a < b for a, b in zip(thresholds, thresholds[1:])), '별점 경계')
    require(all(1 <= level <= 50 for level in data['feature_unlock_levels'].values()), '기능 레벨 범위')
    for key in ('manual_practice', 'core_business', 'core_sales', 'mastery_progress', 'six_slot_access'):
        require(data['feature_unlock_levels'][key] == 1, '핵심 진행의 추가 성장 잠금 금지')
    return data


def flatten(value, prefix=''):
    if isinstance(value, dict):
        for key, child in value.items():
            yield from flatten(child, f'{prefix}.{key}' if prefix else key)
    elif isinstance(value, list) and any(isinstance(v, (dict, list)) for v in value):
        for i, child in enumerate(value):
            yield from flatten(child, f'{prefix}[{i}]')
    else:
        yield prefix, json.dumps(value, ensure_ascii=False)


def render(data):
    text = '''# 개발용 임시 수치 설정

2026-10-16 사용자 요청으로 **조정 가능한 임시 수치 사용**을 승인받았다. 출시값·밸런스 검증 완료는 아니다. 이 문서는 자동 생성하며 직접 수정하지 않는다.

## 1. 수정 원본과 적용 범위

- 원본: [development_balance.json](../../1_app_development/config/development_balance.json). 모든 조정은 이 파일에서 한다.
- 검증·문서 갱신: 저장소 루트에서 `python 1_app_development/tools/development_balance.py`.
- 재생성 확인: `python 1_app_development/tools/development_balance.py --check`.
- 신규 main의 Workshop에는 영업·맛별 연습·재고/6구·손님 판매·승급·도감 소스를 연결했다. 실제 복합 결제·황금/광고 검증·친구 연동은 미완료다. 오디오 기본값만 생성 Dart 상수로 연결하며 공통 계산은 명시적 설정 로더를 사용한다. 전체 게임 흐름·서버 지갑 연동은 아니다. 기존 앱·서버 가격/IAP·의존성은 바꾸지 않았다.
- 향후 해당 기능 구현 시 같은 원본을 읽고 클라이언트/서버 견적의 revision을 확인한다. 상수를 별도로 복사하지 않는다. 서버 구매가격은 서버 배포본이 권위이며 클라이언트가 보낸 가격을 신뢰하지 않는다.
- `fixed_requirements`는 사용자 확정 조건이다. 일반 밸런스 조정과 구분하며 별도 승인 없이 바꾸지 않는다.
- 수치 아닌 미결정은 마지막 목록에 남긴다. 이 값들이 해당 정책의 자동 승인이나 구현/실기기 검수를 대신하지 않는다.

## 2. 수치 해석

금액 buns/effect는 BigInt용 10진 문자열, gold/횟수/ms/각도는 정수다. permille은1000분율, basis_points는10000분율이다. 동일 결과의 재시도는 카운터/지급을 늘리지 않는다.

스킬 n회차는 `ceil(base × (numerator/denominator)^n)`, 황금은 `base_gold + floor(n/gold_step_purchase_count) × gold_step_amount`. 묶음은 개별 올림 후 합산하고 최대 구매는 두 잔액을 함께 확인한다. 현재 스킬 기본 비용/효과를 임시 seed로 보존했고, 신규 황금 비용과 모든 꾸미기/부스트 두 비용은 각각 명시했다. 추가 레시피 표는 획득 순번용이며 가상의 새 맛/출시 콘텐츠 수를 확정하지 않는다.

만족도는 사용자 답변으로 품질·신선도 기반, 일반 대금에 별점 재곱셈 없음으로 확정했다. 가중치·경계는 임시값이다. 미디엄은 인덱스2이며 손기술은 두 반죽·속 방향·일반 판매 익힘 조건을 사용한다. 덜 익음 특별 주문 판매는 별개다. 신규 게임은 붕어빵력·황금붕어빵력 두 재화이며 구형 코인은 신규 개념이 아니다. 일반 대금은 붕어빵력/누적 합산·전량 판매, 미션 황금 서버 검증·수동 승급·명시 종료 정책도 후속 답변으로 확정했다. 추가 맛은 슈크림/초코만 확정하며 후속 미정/외부 조건은 마지막 목록을 따른다.

광고 soft timeout은 대기 UI/재조회 시점이다. 시간 초과만으로 예약을 해제·환불·미당첨 확정하거나 늦은 콜백을 재지급하지 않는다. 검증 window와 보관일은 개발 비교용 목표일 뿐 업체 증거/법정 의무를 대체하지 않는다. 보관일을 개인정보/결제기록의 법정 기간보다 줄이는 근거로 사용하지 않는다. 제안 schema_next_version도 실제 포맷 이전 승인/구현이 아니다.

## 3. 항목별 임시 구매 가격

### 3.1. 스킬

| ID | 기본 붕어빵력 | 기본 황금 | 효과 | 해금 누적 | 증가비 |
| --- | ---: | ---: | ---: | ---: | --- |
'''
    for key, v in data['skill_purchase']['entries'].items():
        text += f"| {key} | {v['buns']} | {v['gold']} | {v['effect']} | {v['unlock_total']} | {v['ratio_numerator']}/{v['ratio_denominator']} |\n"
    text += '\n### 3.2. 꾸미기·부스트\n\n| 종류 | ID | 붕어빵력 | 황금 |\n| --- | --- | ---: | ---: |\n'
    for group in ('cosmetic_purchase', 'boost_purchase'):
        for key, v in data[group].items():
            text += f"| {group} | {key} | {v['buns']} | {v['gold']} |\n"
    text += '\n## 4. Lv.1~50 임시 표\n\n| Lv | 시즌 누적 붕어빵력 | 구간 탭 | 구간 판매 | 주문 맛 상한 | 주문 수량 상한 | 대기 ms | 줄 상한 |\n| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n'
    for v in data['level_progression']:
        text += '| ' + ' | '.join(str(v[k]) for k in ('level', 'season_total_buns', 'additional_taps', 'additional_sales', 'order_flavor_limit', 'order_quantity_limit', 'order_wait_ms', 'max_queue')) + ' |\n'
    text += '\n## 5. 나머지 설정 전체\n\n| 설정 경로 | 임시값/확정값 |\n| --- | --- |\n'
    excluded = {'metadata', 'cosmetic_purchase', 'unresolved_non_numeric_policies', 'avatar_catalog', 'mission_targets'}
    for key, val in data.items():
        if key in excluded:
            continue
        # Above tables hold repeated rows; keep global knobs and rewards visible here.
        if key == 'skill_purchase':
            val = {k: v for k, v in val.items() if k != 'entries'}
        if key == 'level_progression':
            val = {str(v['level']): {'buns_reward': v['buns_reward'], 'gold_reward': v['gold_reward']} for v in val}
        for path, value in flatten(val, key):
            text += f'| `{path}` | `{value}` |\n'
    text += '\n### 출시 아바타 카탈로그: 기존 에셋 재사용, 수치는 임시값\n\n| ID | 이름 | 슬롯 | 기본 무료 | 해금 Lv | 해금 누적 |\n| --- | --- | --- | --- | --- | --- |\n'
    for key, row in data['avatar_catalog'].items():
        text += f"| {key} | {row['label']} | {row['slot']} | {row['free']} | {row['unlock_level']} | {row['unlock_total']} |\n"
    text += '\n### 신규 일일·주간 미션: 구매·자동 생산 포함(사용자 확정), 수치는 임시값\n\n| 기간 | ID | 목표 | 임시 요구 | 황금 보상 |\n| --- | --- | --- | --- | --- |\n'
    for scope, goals in data['mission_targets'].items():
        for key, row in goals.items():
            text += f"| {scope} | {key} | {row['label']} | {row['target']} | {data['mission_gold_rewards'][row['reward_key']]} |\n"
    text += f"\n일일 전체 완료 추가 황금: {data['mission_gold_rewards']['daily_all']}. 모든 황금은 서버 검증 후 지급.\n"
    text += '\n## 6. 아직 수치로 해결할 수 없는 항목\n\n'
    text += '\n'.join('- ' + v for v in data['unresolved_non_numeric_policies']) + '\n\n'
    text += '[이전·복구 위험](13_저장이전과구매복구위험검토.md) · [선행 설계](12_선행기획검토와복구설계.md) · [체크리스트](CHECKLIST.md)\n'
    return text


def render_audio_defaults(data):
    audio = data['audio']
    enabled = 'true' if audio['cooking_enabled_by_default'] else 'false'
    return ("// Generated by tools/development_balance.py; edit config/development_balance.json.\n"
            f"const provisionalDefaultBgmVolume = {audio['bgm_default_percent']};\n"
            f"const provisionalDefaultSfxVolume = {audio['sfx_default_percent']};\n"
            f"const provisionalDefaultCookingVolume = {audio['cooking_default_percent']};\n"
            f"const provisionalDefaultCookingEnabled = {enabled};\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='검증 및 문서 재생성 일치 확인, 파일 변경 없음')
    args = parser.parse_args()
    data = validate(json.loads(CONFIG.read_text(encoding='utf-8')), json.loads(CATALOG.read_text(encoding='utf-8')))
    expected = render(data)
    defaults = ROOT / '1_app_development/lib/development_audio_defaults.dart'
    expected_defaults = render_audio_defaults(data)
    expected_server = json.dumps(data, ensure_ascii=False, indent=2) + '\n'
    if args.check:
        require(SERVER_CONFIG.exists() and SERVER_CONFIG.read_text(encoding='utf-8') == expected_server, '서버 설정 재생성 필요')
        require(defaults.exists() and defaults.read_text(encoding='utf-8') == expected_defaults, '오디오 기본값 재생성 필요')
        require(DOC.exists() and DOC.read_text(encoding='utf-8') == expected, '문서와 설정 불일치: 생성 도구 실행 필요')
    else:
        SERVER_CONFIG.parent.mkdir(parents=True, exist_ok=True)
        SERVER_CONFIG.write_text(expected_server, encoding='utf-8', newline='\n')
        DOC.write_text(expected, encoding='utf-8', newline='\n')
        defaults.write_text(expected_defaults, encoding='utf-8', newline='\n')
    print('임시 수치 구조·확정 요구·가격 전체·레벨 표·문서 일치 확인. 앱 실행/밸런스 검수 아님.')


if __name__ == '__main__':
    main()
