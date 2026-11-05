"""Mutation checks for the private outline validator; no narrative prose in output."""
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('story_audit', ROOT / 'tools/audit_story.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class StoryAuditTests(unittest.TestCase):
    def setUp(self):
        self.graph = json.loads((ROOT / 'data/narrative/story_graph.json').read_text())

    def test_current_outline_is_traversable(self):
        count, reachable, endings = module.audit(self.graph)
        self.assertGreaterEqual(reachable, count)
        self.assertGreater(endings, 0)

    def test_undefined_target_is_rejected(self):
        self.graph['nodes'][0]['edges'][0]['to'] = 'missing'
        with self.assertRaises(AssertionError):
            module.audit(self.graph)

    def test_involuntary_nature_change_is_rejected(self):
        edge = self.graph['nodes'][0]['edges'][0]
        edge['effects'] = {'nature': 'vampire'}
        edge.pop('voluntary', None)
        with self.assertRaisesRegex(AssertionError, 'Involuntary'):
            module.audit(self.graph)

    def test_unreachable_initial_condition_is_rejected(self):
        for edge in self.graph['nodes'][0]['edges']:
            edge['requires'] = {'flags': {'forest_done': True}}
        with self.assertRaisesRegex(AssertionError, 'continuation'):
            module.audit(self.graph)

    def test_unknown_flag_is_rejected(self):
        self.graph['nodes'][0]['edges'][0]['requires'] = {'flags': {'misspelled_flag': True}}
        with self.assertRaises(AssertionError):
            module.audit(self.graph)

    def test_removing_human_route_is_rejected(self):
        node = next(n for n in self.graph['nodes'] if n['id'] == 'n07')
        node['edges'] = [edge for edge in node['edges'] if edge['to'] != 'n08']
        with self.assertRaises(AssertionError):
            module.audit(self.graph)


if __name__ == '__main__':
    unittest.main()
