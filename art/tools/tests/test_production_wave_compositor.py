"""Translation repairs must preserve native artwork and prove pixel ownership."""
import sys
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from production_wave_compositor import labels, repair, source_masks, render, ORDER
from production_wave_compositor import fitted_targets, throughway_target
from hybrid_wave_geometry import generate, metadata, validate, TILES, expected_edges


def illustrated_source(size=128):
    """Unique spatial colors make accidental resampling or scaling detectable."""
    yy,xx=np.indices((size,size))
    return Image.fromarray(np.stack((xx%256,yy%256,(xx*17+yy*13)%256),axis=-1).astype('uint8'))


def vertical_forest(right,size=128):
    return source_masks({'polygons':{'Forest':[
        [[0,0],[right,0],[right,size-1],[0,size-1]]]}},size)


class ProductionWaveCompositorTests(unittest.TestCase):
    def setUp(self):
        self.source=illustrated_source()
        self.origins=vertical_forest(63)
        self.targets=vertical_forest(79)

    def test_identity_preserves_every_pixel(self):
        out,sx,sy,changed=repair(self.source,self.origins,self.origins)
        yy,xx=np.indices((128,128))
        self.assertEqual(out.tobytes(),self.source.tobytes())
        self.assertTrue(np.array_equal(sx,xx))
        self.assertTrue(np.array_equal(sy,yy))
        self.assertFalse(changed.any())

    def test_same_owner_pixels_remain_exact(self):
        out,sx,sy,changed=repair(self.source,self.origins,self.targets)
        original=np.asarray(self.source);final=np.asarray(out)
        yy,xx=np.indices((128,128))
        self.assertTrue(np.array_equal(final[~changed],original[~changed]))
        self.assertTrue(np.array_equal(sx[~changed],xx[~changed]))
        self.assertTrue(np.array_equal(sy[~changed],yy[~changed]))

    def test_repaired_pixels_come_from_recorded_donors(self):
        out,sx,sy,changed=repair(self.source,self.origins,self.targets)
        self.assertTrue(changed.any())
        self.assertTrue(np.array_equal(np.asarray(out),np.asarray(self.source)[sy,sx]))

    def test_every_actual_donor_has_required_feature(self):
        _,sx,sy,_=repair(self.source,self.origins,self.targets)
        self.assertTrue(np.array_equal(labels(self.origins)[sy,sx],labels(self.targets)))

    def test_patch_coordinates_are_integer_translation_only(self):
        _,sx,sy,changed=repair(self.source,self.origins,self.targets)
        yy,xx=np.indices((128,128))
        self.assertTrue(np.issubdtype(sx.dtype,np.integer))
        self.assertTrue(np.issubdtype(sy.dtype,np.integer))
        for y in range(0,128,24):
            for x in range(0,128,24):
                area=np.s_[y:y+24,x:x+24]
                selected=changed[area]
                if selected.any():
                    self.assertEqual(len(np.unique((sx-xx)[area][selected])),1)
                    self.assertEqual(len(np.unique((sy-yy)[area][selected])),1)

    def test_input_source_and_masks_unchanged(self):
        before=self.source.tobytes()
        original={k:v.tobytes() for k,v in self.origins.items()}
        target={k:v.tobytes() for k,v in self.targets.items()}
        repair(self.source,self.origins,self.targets)
        self.assertEqual(self.source.tobytes(),before)
        self.assertEqual(original,{k:v.tobytes() for k,v in self.origins.items()})
        self.assertEqual(target,{k:v.tobytes() for k,v in self.targets.items()})

    def test_repair_is_deterministic(self):
        a=repair(self.source,self.origins,self.targets)
        b=repair(self.source,self.origins,self.targets)
        self.assertEqual(a[0].tobytes(),b[0].tobytes())
        for first,second in zip(a[1:],b[1:]):
            self.assertTrue(np.array_equal(first,second))

    def test_output_native_dimensions_and_coordinate_bounds(self):
        out,sx,sy,changed=repair(self.source,self.origins,self.targets)
        self.assertEqual(out.size,self.source.size)
        self.assertEqual(out.mode,'RGB')
        for array in (sx,sy,changed): self.assertEqual(array.shape,(128,128))
        self.assertGreaterEqual(int(sx.min()),0);self.assertLess(int(sx.max()),128)
        self.assertGreaterEqual(int(sy.min()),0);self.assertLess(int(sy.max()),128)

    def test_missing_safe_donor_fails(self):
        origins={'Field':Image.new('L',(128,128),255)}
        with self.assertRaisesRegex(ValueError,'No safe source donor for Forest'):
            repair(self.source,origins,self.targets)

    def test_membership_dimension_mismatch_fails(self):
        with self.assertRaisesRegex(ValueError,'membership dimensions'):
            repair(self.source,self.origins,vertical_forest(30,100))

    def test_source_polygon_inclusive_boundary(self):
        masks=source_masks({'polygons':{'Forest':[[[10,10],[40,10],[40,40],[10,40]]]}},128)
        self.assertEqual(np.count_nonzero(np.asarray(masks['Forest'])),31*31)
        self.assertEqual(masks['Forest'].getpixel((40,40)),255)
        self.assertEqual(masks['Field'].getpixel((41,40)),255)

    def test_source_polygons_union_and_complement(self):
        masks=source_masks({'polygons':{'Forest':[
            [[10,10],[30,10],[30,30],[10,30]],
            [[70,70],[90,70],[90,90],[70,90]]]}},128)
        forest=np.asarray(masks['Forest'])
        self.assertEqual(np.count_nonzero(forest),2*21*21)
        self.assertTrue(np.array_equal(forest+np.asarray(masks['Field']),np.full((128,128),255)))

    def test_overlap_keeps_membership_but_road_is_visible_owner(self):
        masks=generate('settlement_road_throughway',size=128)
        overlap=(np.asarray(masks['Settlement'])!=0)&(np.asarray(masks['Road'])!=0)
        self.assertTrue(overlap.any())
        self.assertTrue((labels(masks)[overlap]==ORDER.index('Road')).all())
        self.assertTrue(validate(masks,metadata('settlement_road_throughway',size=128))['valid'])

    def test_crossing_identity_repair_preserves_feature_layers(self):
        masks=generate('settlement_road_throughway',size=128)
        before={k:v.tobytes() for k,v in masks.items()}
        out,sx,sy,changed=repair(self.source,masks,masks)
        self.assertFalse(changed.any())
        self.assertEqual(out.tobytes(),self.source.tobytes())
        self.assertEqual(before,{k:v.tobytes() for k,v in masks.items()})
        self.assertTrue(np.array_equal(labels(masks)[sy,sx],labels(masks)))

    def test_multiple_feature_repairs_keep_separate_owners(self):
        def strips(bounds):
            polygons={}
            for name,(lo,hi) in zip(('Forest','Road','River'),bounds):
                polygons[name]=[[[lo,0],[hi,0],[hi,255],[lo,255]]]
            return source_masks({'polygons':polygons},256)
        source=illustrated_source(256)
        origins=strips(((64,127),(128,191),(192,255)))
        targets=strips(((70,132),(133,197),(198,255)))
        out,sx,sy,changed=repair(source,origins,targets)
        self.assertTrue(changed.any())
        self.assertTrue(np.array_equal(labels(origins)[sy,sx],labels(targets)))
        self.assertTrue(np.array_equal(np.asarray(out),np.asarray(source)[sy,sx]))

    def test_render_rejects_non_native_input(self):
        with self.assertRaisesRegex(ValueError,'native1254'):
            render(self.source,{'polygons':{'Settlement':[
                [[0,0],[127,0],[127,40],[0,40]]]}},'settlement_throughway')

    def test_native_fitted_targets_validate_all_eight_without_mutating_inputs(self):
        for tile in TILES:
            with self.subTest(tile=tile):
                origins=generate(tile)
                before={k:v.tobytes() for k,v in origins.items()}
                targets=fitted_targets(origins,tile)
                report=validate(targets,metadata(tile))
                self.assertTrue(report['valid'],report)
                self.assertEqual(before,{k:v.tobytes() for k,v in origins.items()})
                self.assertTrue(all(m.size==(1254,1254) for m in targets.values()))

    def test_fitted_sockets_and_full_edges_survive_all_quarter_turns(self):
        for tile in TILES:
            targets=fitted_targets(generate(tile),tile)
            for name,image in targets.items():
                expected=expected_edges(metadata(tile),name)
                pixels=np.asarray(image)
                for turns in range(4):
                    actual=np.rot90(pixels,-turns)
                    edges=dict(N=actual[0],E=actual[:,-1],S=actual[-1],W=actual[:,0])
                    for side in 'NESW':
                        with self.subTest(tile=tile,feature=name,turns=turns,side=side):
                            self.assertTrue(np.array_equal(edges[side],expected[side]))
                    expected=dict(N=expected['W'][::-1],E=expected['N'],
                                  S=expected['E'][::-1],W=expected['S'])
                for feature,width,lo,hi in (('Road',126,564,689),('River',250,502,751)):
                    if name==feature:
                        for side,declared in metadata(tile)['edges'].items():
                            if declared==feature:
                                edge={'N':pixels[0],'E':pixels[:,-1],
                                      'S':pixels[-1],'W':pixels[:,0]}[side]
                                self.assertEqual(np.flatnonzero(edge).tolist(),list(range(lo,hi+1)))
                                self.assertEqual(np.count_nonzero(edge),width)

    def test_fitted_canonical_interior_memberships_unchanged(self):
        for tile in TILES:
            origins=generate(tile)
            targets=fitted_targets(origins,tile)
            for name in origins:
                self.assertTrue(np.array_equal(np.asarray(origins[name])[96:-96,96:-96],
                                               np.asarray(targets[name])[96:-96,96:-96]))

    def test_narrow_throughway_retains_core_and_joins_full_north_south(self):
        origins=source_masks({'polygons':{'Settlement':[
            [[500,0],[753,0],[753,1253],[500,1253]]]}},1254)
        targets=throughway_target(origins)
        city=np.asarray(targets['Settlement'])
        self.assertTrue(np.array_equal(city[96:-96],np.asarray(origins['Settlement'])[96:-96]))
        self.assertTrue((city[0]==255).all())
        self.assertTrue((city[-1]==255).all())
        self.assertFalse(city[1:-1,0].any())
        self.assertFalse(city[1:-1,-1].any())
        report=validate(targets,metadata('settlement_throughway'))
        self.assertTrue(report['valid'],report)
        self.assertEqual(report['feature_components'],{'Settlement':1})

    def test_native_corner_fan_repairs_never_scale_or_change_core_rgb(self):
        source=illustrated_source(1254)
        origins=source_masks({'polygons':{'Settlement':[
            [[500,0],[753,0],[753,1253],[500,1253]]]}},1254)
        target=throughway_target(origins)
        before=source.tobytes()
        out,sx,sy,changed=repair(source,origins,target)
        self.assertEqual(out.size,(1254,1254))
        self.assertEqual(before,source.tobytes())
        self.assertFalse(changed[96:-96].any())
        self.assertTrue(np.array_equal(np.asarray(out)[96:-96],np.asarray(source)[96:-96]))
        self.assertTrue(np.array_equal(np.asarray(out),np.asarray(source)[sy,sx]))
        self.assertTrue(np.array_equal(labels(origins)[sy,sx],labels(target)))

    def test_render_normalizes_gate_overlap_and_preserves_single_features(self):
        calibration={'polygons':{
            'Settlement':[[[0,0],[1253,0],[1253,400],[0,400]]],
            'Road':[[[600,300],[1253,300],[1253,689],[600,689]]],
        }}
        source=illustrated_source(1254)
        out,targets,origins,sx,sy,_=render(source,calibration,'settlement_gate')
        for masks in (origins,targets):
            self.assertFalse(((np.asarray(masks['Settlement'])>0)&(np.asarray(masks['Road'])>0)).any())
        report=validate(targets,metadata('settlement_gate'))
        self.assertTrue(report['valid'],report)
        self.assertEqual(report['feature_components'],{'Settlement':1,'Road':1})
        self.assertTrue(np.array_equal(np.asarray(out),np.asarray(source)[sy,sx]))

    def test_render_keeps_allowed_throughway_membership_crossing(self):
        calibration={'polygons':{
            'Settlement':[[[400,0],[853,0],[853,1253],[400,1253]]],
            'Road':[[[0,564],[1253,564],[1253,689],[0,689]]],
        }}
        source=illustrated_source(1254)
        out,targets,origins,sx,sy,_=render(source,calibration,'settlement_road_throughway')
        for masks in (origins,targets):
            overlap=(np.asarray(masks['Settlement'])>0)&(np.asarray(masks['Road'])>0)
            self.assertTrue(overlap.any())
            self.assertFalse(overlap[[0,-1]].any())
            self.assertFalse(overlap[:,[0,-1]].any())
            self.assertTrue((labels(masks)[overlap]==ORDER.index('Road')).all())
        report=validate(targets,metadata('settlement_road_throughway'))
        self.assertTrue(report['valid'],report)
        self.assertTrue(np.array_equal(np.asarray(out),np.asarray(source)[sy,sx]))


if __name__=='__main__': unittest.main()
