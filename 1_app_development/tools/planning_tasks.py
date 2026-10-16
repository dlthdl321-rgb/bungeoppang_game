"""한국어 개발 작업 상태 관리. Python 표준 라이브러리만 사용한다."""
import argparse
import copy
import json
import os
from pathlib import Path
import tempfile
import sys
from datetime import date, datetime, timezone, timedelta

STATES = ('미착수', '진행 중', '검토 중', '완료', '차단')
ROOT = Path(__file__).resolve().parents[2] / '2_development_plans_and_checklists' / '2.1_development_specs_tasks_and_progress'
for stream in (sys.stdout, sys.stderr):
    if hasattr(stream, 'reconfigure'):
        stream.reconfigure(encoding='utf-8')


def now():
    return datetime.now(timezone(timedelta(hours=9))).isoformat(timespec='seconds')


def atomic(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(dir=path.parent, prefix=path.name + '.', suffix='.tmp')
    try:
        with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as stream:
            stream.write(value)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def read(root):
    data = json.loads((root / 'tasks.json').read_text(encoding='utf-8-sig'))
    ids = [t['id'] for t in data['tasks']]
    if len(ids) != len(set(ids)):
        raise ValueError('중복 작업 ID')
    for t in data['tasks']:
        estimate = t['estimated_hours']
        if t['status'] not in STATES or (estimate is not None and
                (isinstance(estimate, bool) or not isinstance(estimate, (int, float)) or estimate <= 0)):
            raise ValueError('잘못된 상태 또는 예상 시간')
        if estimate is None and t.get('estimate_status') not in ('미산정', '재산정 필요'):
            raise ValueError('예상 시간 미정에는 estimate_status 미산정/재산정 필요를 명시해야 함')
        if any(dep not in ids or dep == t['id'] for dep in t['dependencies']):
            raise ValueError('잘못된 선행 작업')
        for field in ('start_date', 'end_date'):
            if t[field]:
                date.fromisoformat(t[field])
        if t['start_date'] and t['end_date'] and t['start_date'] > t['end_date']:
            raise ValueError('시작일이 종료일보다 늦음')
        verification = t['verification_result'].strip()
        if t['status'] == '완료' and (not verification or
                not t['implementation_evidence'].strip() or verification in ('미실행', '없음', '미정') or
                verification.startswith('미실행:')):
            raise ValueError('완료에는 구현 근거와 실행한 검증 결과가 필요함')
        if t['status'] == '차단' and not t['block_reason'].strip():
            raise ValueError('차단 사유 필요')
    visiting, visited = set(), set()
    by_id = {t['id']: t for t in data['tasks']}
    def visit(key):
        if key in visiting:
            raise ValueError('선행 작업 순환')
        if key in visited:
            return
        visiting.add(key)
        for dep in by_id[key]['dependencies']:
            visit(dep)
        visiting.remove(key)
        visited.add(key)
    for key in ids:
        visit(key)
    for t in data['tasks']:
        if t['status'] == '완료' and any(by_id[dep]['status'] != '완료' for dep in t['dependencies']):
            raise ValueError('완료 작업에 미완료 선행 작업이 있음: ' + t['id'])
    return data


def clean(value):
    return str(value).replace('|', '／').replace('\n', ' ')


def render(root, data, today=None):
    today = today or now()[:10]
    tasks = data['tasks']
    done = [t for t in tasks if t['status'] == '완료']
    hours = sum(t['estimated_hours'] or 0 for t in tasks)
    earned = sum(t['estimated_hours'] or 0 for t in done)
    unknown = sum(t['estimated_hours'] is None for t in tasks)
    needs_review = data.get('planning_basis', {}).get('estimates_need_review', False)
    incomplete_estimates = unknown > 0 or needs_review
    time_summary = (f'전체 예상 시간: 미정 · 미산정 작업 {unknown}개 · '
                    f'개정 전/기등록 참고 추정 합 {hours:g}시간 (최신 전체 시간 아님)\n\n'
                    '예상 시간 가중 진행률: 재산정 완료 전 제공하지 않음\n\n'
                    if incomplete_estimates else
                    f"예상 시간 가중 진행률: {earned:g}/{hours:g}시간 ({earned/hours*100 if hours else 0:.1f}%)\n\n")
    common = (f"원본: `tasks.json` · 기준일: {today}(한국 시각) · 갱신: {data['updated_at']}\n\n"
              f"완료 작업 수: {len(done)}/{len(tasks)} ({len(done)/len(tasks)*100 if tasks else 0:.1f}%)\n\n" +
              time_summary +
              "진행 중·검토 중의 부분 진행률은 합산하지 않는다. 문서 작성은 게임 구현 완료가 아니다.\n")
    def estimate_label(t):
        if t['estimated_hours'] is None:
            return '미산정'
        label = f"{t['estimated_hours']:g}시간"
        if needs_review or t.get('estimate_status') == '개정 전 참고·재산정 필요':
            label += ' (개정 전 참고·재산정 필요)'
        return label
    checklist = ('# 개발 체크리스트\n\n자동 생성 문서. 직접 수정하지 않는다.\n\n'
                 '작업 이름을 누르면 아래의 해당 작업 상세로 이동한다. 상세 내용은 tasks.json에서 자동 생성한다.\n\n') + common
    for stage in ('P1', 'P2', 'P3', 'P4', 'P5', 'P6'):
        checklist += f'\n## {stage}\n\n'
        for t in tasks:
            if t['phase'] == stage:
                checklist += f"- [{'x' if t['status'] == '완료' else ' '}] [{t['id']} {clean(t['name'])}](#{t['id'].lower()}) — {t['status']} / {estimate_label(t)} / 담당: {clean(t['owner'])}\n"
    stage_docs = {
        'P1': '2.1.2_development_phase_plans/P1_재화와저장.md', 'P2': '2.1.2_development_phase_plans/P2_배경과오디오.md',
        'P3': '2.1.2_development_phase_plans/P3_레시피와해금.md', 'P4': '2.1.2_development_phase_plans/P4_제작미니게임.md',
        'P5': '2.1.2_development_phase_plans/P5_6칸굽기판.md', 'P6': '2.1.2_development_phase_plans/P6_통합과검수.md',
    }
    checklist += '\n## 작업 상세\n'
    for t in tasks:
        checklist += f"\n### {t['id']}\n\n**{clean(t['name'])}**\n\n"
        checklist += '| 항목 | 내용 |\n| --- | --- |\n'
        fields = [
            ('상태·담당', f"{t['status']} / {t['owner']}"),
            ('요구사항', ', '.join(t['req_ids'])),
            ('우선순위·예상 시간', f"{t['priority']} / {estimate_label(t)}"),
            ('예정 날짜', f"{t['start_date'] or '미정'} ~ {t['end_date'] or '미정'}"),
            ('산출물', t.get('deliverables', '미정')),
            ('완료 조건', t['completion_criteria']),
            ('검수 방법', t['verification_method']),
            ('검증 결과', t['verification_result']),
            ('구현 근거·현재 확인', t['implementation_evidence']),
            ('차단 사유', t['block_reason'] or '없음'),
        ]
        for label, value in fields:
            checklist += f'| {label} | {clean(value)} |\n'
        dependencies = ', '.join(f'[{dep}](#{dep.lower()})' for dep in t['dependencies']) or '없음'
        checklist += f'\n선행 작업: {dependencies}\n\n'
        checklist += (f"관련 문서: [단계별 기획]({stage_docs[t['phase']]}) · "
                      '[상세 기획](02_상세기획서.md) · [기술 설계](05_기술설계.md) · '
                      '[저장 이전](06_저장데이터이전.md) · [일정](04_2주개발일정.md) · '
                      '[성장 난이도](07_성장난이도.md) · '
                      '[개발 도구·Android 출시](08_개발도구와안드로이드출시.md) · '
                      '[최신 검수 기준](09_통합검수기준.md) · '
                      '[복합 경제·50레벨](10_복합경제와50레벨해금.md) · '
                      '[하루2회 보상광고](11_하루2회보상형광고.md)\n\n')
        checklist += ('검수 ID(영향·회귀 범위): ' + ', '.join(t.get('acceptance_ids', [])) +
                      '\n\n[검수 ID 원문 위치](최종검증보고.md#검수-id-원문-위치) · '
                      f"[단계 목록으로 돌아가기](#{t['phase'].lower()})\n")
    report = '# 진행현황\n\n자동 생성 문서. 직접 수정하지 않는다.\n\n' + common
    report += '\n## 상태 집계\n\n| 상태 | 작업 수 | 참고 추정 합 | 미산정 작업 |\n| --- | ---: | ---: | ---: |\n'
    for state in STATES:
        subset = [t for t in tasks if t['status'] == state]
        report += f"| {state} | {len(subset)} | {sum(t['estimated_hours'] or 0 for t in subset):g} | {sum(t['estimated_hours'] is None for t in subset)} |\n"
    def section(title, subset):
        nonlocal report
        report += f'\n## {title}\n\n'
        report += '\n'.join(f"- {t['id']} {t['name']} ({t['status']}) — {clean(t['block_reason'] or '차단 사유 없음')}" for t in subset) or '해당 없음.'
        report += '\n'
    section('지연 작업', [t for t in tasks if t['end_date'] and t['end_date'] < today and t['status'] != '완료'])
    section('차단 작업', [t for t in tasks if t['status'] == '차단'])
    for state in STATES:
        section(state, [t for t in tasks if t['status'] == state])
    report += '\n## 날짜별 작업\n\n| 날짜 | 작업 ID |\n| --- | --- |\n'
    dates = sorted({t['start_date'] for t in tasks if t['start_date']} | {t['end_date'] for t in tasks if t['end_date']})
    if dates:
        day = date.fromisoformat(dates[0])
        while day.isoformat() <= dates[-1]:
            key = day.isoformat()
            active = [t['id'] for t in tasks if t['start_date'] and t['end_date'] and t['start_date'] <= key <= t['end_date']]
            report += f"| {key} | {', '.join(active) or '없음'} |\n"
            day += timedelta(days=1)
    else:
        report += '| 미정 | 공통 기준 시작일 확인 후 배정 |\n'
    atomic(root / 'CHECKLIST.md', checklist)
    atomic(root / '진행현황.md', report)


def recover(root):
    pending = root / '.planning_pending.json'
    if not pending.exists():
        return
    transaction = json.loads(pending.read_text(encoding='utf-8'))
    atomic(root / 'tasks.json', json.dumps(transaction['data'], ensure_ascii=False, indent=2) + '\n')
    atomic(root / 'task_history.jsonl', transaction['history'])
    render(root, transaction['data'])
    pending.unlink()


def update(root, args):
    data = read(root)
    target = next((t for t in data['tasks'] if t['id'] == args.id), None)
    if target is None:
        raise ValueError('존재하지 않는 작업 ID: ' + args.id)
    before = copy.deepcopy(target)
    for option, field in (('status', 'status'), ('owner', 'owner'), ('block_reason', 'block_reason'),
                          ('verification', 'verification_result'), ('evidence', 'implementation_evidence')):
        value = getattr(args, option)
        if value is not None:
            target[field] = value
    if target['status'] == '완료':
        if not args.verification or not args.evidence or not args.verification.strip() or args.verification.strip() in ('미실행', '없음', '미정') or args.verification.strip().startswith('미실행:') or not args.evidence.strip():
            raise ValueError('완료 변경에는 --verification 실행 결과와 --evidence 구현 근거를 명시해야 함')
        incomplete = [dep for dep in target['dependencies'] if next(t for t in data['tasks'] if t['id'] == dep)['status'] != '완료']
        if incomplete:
            raise ValueError('미완료 선행 작업: ' + ', '.join(incomplete))
    if target['status'] == '차단' and not target['block_reason'].strip():
        raise ValueError('차단에는 --block-reason 필요')
    if target['status'] != '완료':
        completed_dependents = [t['id'] for t in data['tasks']
                                if t['status'] == '완료' and target['id'] in t['dependencies']]
        if completed_dependents:
            raise ValueError('완료된 후속 작업을 먼저 재검토해야 함: ' + ', '.join(completed_dependents))
    target['updated_at'] = data['updated_at'] = now()
    history_path = root / 'task_history.jsonl'
    history = history_path.read_text(encoding='utf-8') if history_path.exists() else ''
    event = {'timestamp': now(), 'task_id': args.id, 'before': before, 'after': target}
    history += json.dumps(event, ensure_ascii=False) + '\n'
    # 복구 저널을 먼저 저장한다. 중단 후 다음 실행에서 동일 변경을 재생한다.
    atomic(root / '.planning_pending.json', json.dumps({'data': data, 'history': history}, ensure_ascii=False))
    recover(root)


def main():
    parser = argparse.ArgumentParser(description='한국어 작업 상태 관리. 완료는 구현 근거와 실행 검증 결과가 필요합니다.')
    parser.add_argument('--root', type=Path, default=ROOT, help='데이터 폴더(검증 시 임시 폴더 사용)')
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('render', help='원본에서 체크리스트·진행현황 재생성')
    listing = commands.add_parser('list', help='상태·지연·차단·날짜별 작업 조회')
    listing.add_argument('--status', choices=STATES)
    listing.add_argument('--date', help='YYYY-MM-DD, 해당 날짜 진행 예정 작업')
    listing.add_argument('--delayed', action='store_true')
    listing.add_argument('--blocked', action='store_true')
    change = commands.add_parser('update', help='작업 변경 및 이력 저장·문서 재생성')
    change.add_argument('id')
    change.add_argument('--status', choices=STATES)
    change.add_argument('--owner')
    change.add_argument('--block-reason')
    change.add_argument('--verification', help='실행 명령·일시·결과 또는 검수 기록')
    change.add_argument('--evidence', help='구현 파일·심볼·산출물 근거')
    args = parser.parse_args()
    args.root.mkdir(parents=True, exist_ok=True)
    # 동시 갱신을 거부한다. 비정상 종료로 남은 잠금은 실행 프로세스 확인 후 수동 제거한다.
    lock = args.root / '.planning.lock'
    try:
        with lock.open('x', encoding='utf-8') as stream:
            stream.write(str(os.getpid()))
    except FileExistsError:
        parser.exit(2, '다른 갱신 실행 또는 남은 잠금이 있습니다: ' + str(lock) + '\n')
    try:
        recover(args.root)
        data = read(args.root)
        if args.command == 'update':
            if not any(getattr(args, k) is not None for k in ('status', 'owner', 'block_reason', 'verification', 'evidence')):
                raise ValueError('변경할 항목을 지정하세요')
            update(args.root, args)
            print('변경·이력 저장·문서 재생성 완료: ' + args.id)
        elif args.command == 'render':
            render(args.root, data)
            print('체크리스트·진행현황 재생성 완료')
        else:
            if args.date:
                date.fromisoformat(args.date)
            for t in data['tasks']:
                if args.status and t['status'] != args.status:
                    continue
                if args.blocked and t['status'] != '차단':
                    continue
                if args.delayed and not (t['end_date'] and t['end_date'] < now()[:10] and t['status'] != '완료'):
                    continue
                if args.date and not (t['start_date'] and t['end_date'] and t['start_date'] <= args.date <= t['end_date']):
                    continue
                print(t['id'], t['status'], t['name'], t['start_date'] or '날짜 미정', t['end_date'] or '날짜 미정')
    except (ValueError, KeyError, OSError) as error:
        parser.exit(2, str(error) + '\n')
    finally:
        lock.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
