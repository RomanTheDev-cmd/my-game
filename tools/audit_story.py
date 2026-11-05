"""Audit the private scenario graph. Reports opaque IDs, never story text."""
import json
from collections import deque
from pathlib import Path


def audit(graph):
    nodes = graph.get('nodes', [])
    by_id = {node['id']: node for node in nodes}
    assert len(by_id) == len(nodes), 'Duplicate scenario IDs'
    assert graph['start'] in by_id, 'Missing start'
    flags = set(graph['flags'])
    natures = set(graph['natures'])
    assert 'human' in natures
    for node in nodes:
        assert bool(node.get('edges')) != bool(node.get('terminal')), 'Node must have edges or be terminal'
        assert set(node.get('must_have_flags', [])) <= flags, 'Unknown terminal flag'
        for edge in node['edges']:
            assert edge['to'] in by_id, 'Undefined edge target'
            requires, effects = edge.get('requires', {}), edge.get('effects', {})
            assert set(requires) <= {'flags', 'nature'} and set(effects) <= {'flags', 'nature'}
            assert set(requires.get('flags', {})) <= flags and set(effects.get('flags', {})) <= flags
            assert all(type(value) is bool for value in requires.get('flags', {}).values())
            assert all(type(value) is bool for value in effects.get('flags', {}).values())
            assert set(requires.get('nature', [])) <= natures
            if 'nature' in effects:
                assert effects['nature'] in natures and edge.get('voluntary') is True, 'Involuntary nature change'

    def walk(allow_transform):
        queue = deque([(graph['start'], 'human', frozenset())])
        visited, terminals = set(), set()
        while queue:
            state = queue.popleft()
            if state in visited:
                continue
            visited.add(state)
            ident, nature, enabled = state
            node = by_id[ident]
            if node.get('terminal'):
                assert set(node.get('must_have_flags', [])) <= enabled, 'Required companion state lost'
                terminals.add(state)
                continue
            next_states = []
            for edge in node['edges']:
                requires, effects = edge.get('requires', {}), edge.get('effects', {})
                if nature not in requires.get('nature', natures):
                    continue
                if any((flag in enabled) != value for flag, value in requires.get('flags', {}).items()):
                    continue
                after_nature = effects.get('nature', nature)
                if not allow_transform and after_nature != nature:
                    continue
                after_flags = set(enabled)
                for flag, value in effects.get('flags', {}).items():
                    (after_flags.add if value else after_flags.discard)(flag)
                next_states.append((edge['to'], after_nature, frozenset(after_flags)))
            assert next_states, 'Reachable nonterminal has no legal continuation: ' + ident
            queue.extend(next_states)
        return visited, terminals

    visited, endings = walk(True)
    human_states, human_endings = walk(False)
    assert {state[0] for state in visited} == set(by_id), 'Unreachable scenario nodes'
    assert {state[1] for state in endings} == natures, 'A nature cannot finish the outline'
    assert human_endings, 'Human path requires transformation'
    mandatory = {node['id'] for node in nodes if node.get('mandatory')}
    assert mandatory <= {state[0] for state in human_states}, 'Human path misses a mandatory node'
    assert any('cured' in state[2] and 'scar' in state[2] for state in endings), 'Cured history is lost'
    return len(nodes), len(visited), len(endings)


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1]
    graph = json.loads((root / 'data/narrative/story_graph.json').read_text())
    texts = json.loads((root / 'data/narrative/story.ru.json').read_text())['sequences']
    assert all(node['text'] in texts for node in graph['nodes']), 'Missing internal sequence text'
    count, states, endings = audit(graph)
    print(f'Internal outline: {count} nodes, {states} reachable states, structural checks passed; campaign integration pending')
