"""Regression tests for exact hybrid feature membership and declared topology."""
import hashlib
import json
import sys
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from hybrid_wave_geometry import TILES, generate, metadata, validate, expected_edges
from mask_utils import rotate_mask


class HybridWaveGeometryTests(unittest.TestCase):
    size = 256

    def check_tile(self,tile):
        report = validate(generate(tile,size=self.size),metadata(tile,size=self.size))
        self.assertTrue(report['valid'],report)

    def test_settlement_throughway(self):
        self.check_tile('settlement_throughway')

    def test_settlement_gate(self):
        self.check_tile('settlement_gate')

    def test_riverside_hamlet(self):
        self.check_tile('riverside_hamlet')

    def test_woodland_road(self):
        self.check_tile('woodland_road')

    def test_woodland_river(self):
        self.check_tile('woodland_river')

    def test_settlement_corner_gate(self):
        self.check_tile('settlement_corner_gate')

    def test_settlement_road_bend(self):
        self.check_tile('settlement_road_bend')

    def test_settlement_road_throughway(self):
        self.check_tile('settlement_road_throughway')

    def test_native_socket_constants(self):
        record = metadata('riverside_hamlet')
        self.assertEqual(record['road_socket'],dict(width=126,inclusive=[564,689],center=626.5))
        self.assertEqual(record['river_socket'],dict(width=250,inclusive=[502,751],center=626.5))

    def test_all_seed_variants_remain_legal(self):
        for seed in (0,1,17,41,73,99):
            for tile in TILES:
                with self.subTest(seed=seed,tile=tile):
                    self.assertTrue(validate(generate(tile,seed,self.size),
                                             metadata(tile,seed,self.size))['valid'])

    def test_deterministic_seed(self):
        for tile in TILES:
            a,b = generate(tile,41,self.size),generate(tile,41,self.size)
            self.assertEqual({k:v.tobytes() for k,v in a.items()},
                             {k:v.tobytes() for k,v in b.items()})

    def test_seed_changes_only_interior(self):
        for tile in TILES:
            a,b = generate(tile,41,self.size),generate(tile,73,self.size)
            self.assertTrue(any(a[k].tobytes()!=b[k].tobytes() for k in a))
            for name in a:
                aa,bb=np.asarray(a[name]),np.asarray(b[name])
                self.assertTrue(np.array_equal(aa[[0,-1]],bb[[0,-1]]))
                self.assertTrue(np.array_equal(aa[:,[0,-1]],bb[:,[0,-1]]))

    def test_rotation_exact_and_lossless(self):
        for tile in TILES:
            for name,image in generate(tile,size=self.size).items():
                for turns in range(4):
                    actual=rotate_mask(image,turns)
                    self.assertEqual(actual.tobytes(),np.rot90(np.asarray(image),-turns).tobytes())
                    self.assertEqual(rotate_mask(actual,-turns).tobytes(),image.tobytes())

    def test_throughway_overlap_interior_only(self):
        masks=generate('settlement_road_throughway',size=self.size)
        overlap=(np.asarray(masks['Settlement'])!=0)&(np.asarray(masks['Road'])!=0)
        self.assertTrue(overlap.any())
        self.assertFalse(overlap[[0,-1]].any())
        self.assertFalse(overlap[:,[0,-1]].any())

    def test_other_feature_masks_exclusive(self):
        for tile in TILES:
            if tile=='settlement_road_throughway': continue
            arrays=[np.asarray(m)!=0 for m in generate(tile,size=self.size).values()]
            self.assertTrue((np.sum(arrays,axis=0)==1).all())

    def test_field_is_exact_complement(self):
        for tile in TILES:
            masks=generate(tile,size=self.size)
            feature=np.logical_or.reduce([np.asarray(m)!=0 for k,m in masks.items() if k!='Field'])
            self.assertTrue(np.array_equal(np.asarray(masks['Field'])!=0,~feature))

    def test_unlisted_socket_rejected(self):
        tile='settlement_corner_gate'
        masks=generate(tile,size=self.size)
        masks['Road'].putpixel((0,self.size//2),255)
        self.assertFalse(validate(masks,metadata(tile,size=self.size))['valid'])

    def test_missing_contact_rejected(self):
        tile='settlement_gate'
        masks=generate(tile,size=self.size)
        masks['Road']=Image.new('L',(self.size,self.size))
        report=validate(masks,metadata(tile,size=self.size))
        self.assertFalse(report['checks']['Road_Settlement_access'])

    def test_forged_topology_rejected(self):
        tile='woodland_river'
        record=metadata(tile,size=self.size)
        record['relationships']=[]
        self.assertFalse(validate(generate(tile,size=self.size),record)['valid'])

    def test_disconnected_extra_component_rejected(self):
        tile='woodland_road'
        masks=generate(tile,size=self.size)
        masks['Forest'].putpixel((4,self.size-5),255)
        self.assertFalse(validate(masks,metadata(tile,size=self.size))['checks']['Forest_one_connected_component'])

    def test_unknown_tile_rejected(self):
        with self.assertRaises(ValueError): generate('founding_tile')

    def test_saved_native_templates_match_generator_without_modification(self):
        root=Path(__file__).resolve().parents[2]/'templates/production_wave_01'
        for tile in TILES:
            for name,expected in generate(tile).items():
                path=root/tile/f'{name}.png'
                before=hashlib.sha256(path.read_bytes()).hexdigest()
                with Image.open(path) as actual:
                    self.assertEqual(actual.size,(1254,1254))
                    self.assertEqual(actual.tobytes(),expected.tobytes())
                self.assertEqual(before,hashlib.sha256(path.read_bytes()).hexdigest())
            record=json.loads((root/tile/'topology.json').read_text())
            self.assertTrue(validate(generate(tile),record)['valid'])


if __name__=='__main__': unittest.main()
