"""Formula examples and boundary checks, not a game implementation.

Run: python formula_audit.py
Uses only the Python standard library. Reads prototype_config.json beside it.
The checks do not validate networking, full offline production, or engine performance.
"""
from __future__ import annotations
import json
import math
import unittest
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parent
CFG = json.loads((ROOT / "prototype_config.json").read_text(encoding="utf-8"))


def land_ledger(area: int, protection: int = 0, seep: float = 10.0,
                base: int = 64, tax: float = 0.1, budget: float = 2.4) -> dict[str, float | int]:
    if min(area, protection, seep, base, tax, budget) < 0:
        raise ValueError("All land inputs must be nonnegative.")
    free = min(area, base + protection)
    uncovered = area - free
    paid = uncovered if tax == 0 else min(uncovered, math.floor((min(budget, seep) + 1e-9) / tax))
    maintenance = paid * tax
    return {"free": free, "uncovered": uncovered, "paid": paid,
            "dormant": uncovered - paid, "maintenance": maintenance, "inflow": seep - maintenance}


def land_efficiency(coverage: float, floor: float = 0.35, sensitivity: float = 1.0) -> float:
    if not all(0 <= x <= 1 for x in (coverage, floor, sensitivity)):
        raise ValueError("Coverage, floor, sensitivity must be in [0, 1].")
    return 1 - sensitivity * (1 - floor) * (1 - coverage)


def world_capacity(realm: int, installed: int) -> int:
    if realm < 0 or installed < 0:
        raise ValueError("Negative capacity inputs.")
    if realm == 0:
        return 0
    return min(16, realm + 1 + min(installed, 2 * realm + 2))


def formation_bonus(actual_q: float, saturated_q: float, nominal: float) -> float:
    if min(actual_q, saturated_q, nominal) < 0:
        raise ValueError("Negative formation inputs.")
    return 0.0 if saturated_q == 0 else nominal * min(1.0, actual_q / saturated_q)


def stacked_bonus(bonuses: Iterable[float], hard_cap: float) -> float:
    values = list(bonuses)
    if hard_cap < 0 or any(x < 0 for x in values):
        raise ValueError("Negative bonus.")
    return min(hard_cap, sum(values))


def triangle_area(points: list[tuple[float, float]]) -> float:
    if len(points) != 3:
        raise ValueError("Three vertices required.")
    (x1, y1), (x2, y2), (x3, y3) = points
    return abs((x2 - x1) * (y3 - y1) - (y2 - y1) * (x3 - x1)) / 2


def periodic_on_integral(t: float, period: float, on_time: float) -> float:
    """On duration from time 0, with a visit at every k*period starting at 0."""
    if t < 0 or period <= 0 or on_time < 0:
        raise ValueError("Invalid periodic input.")
    on = min(period, on_time)
    n = math.floor(t / period)
    return n * on + min(t - n * period, on)


def periodic_on_duration(start: float, end: float, period: float, on_time: float) -> float:
    if end < start:
        raise ValueError("End precedes start.")
    return periodic_on_integral(end, period, on_time) - periodic_on_integral(start, period, on_time)


def chase_mean_multiplier(covered: int, total: int, period_seconds: float,
                          trail_seconds: float = 30.0, bonus: float = 0.5) -> float:
    if total <= 0 or not 0 <= covered <= total or period_seconds <= 0:
        raise ValueError("Invalid chase input.")
    return 1 + bonus * min(1.0, trail_seconds / period_seconds) * covered / total


def stock_state(on: bool, available: float, projected: float, low: float, high: float) -> bool:
    if not 0 <= low < high or available < 0 or projected < available:
        raise ValueError("Invalid stock state inputs.")
    if on and projected >= high:
        return False
    if not on and available <= low:
        # Do not create redundant work already reserved in progress.
        return projected < high
    return on


def normalized_rotate(shape: set[tuple[int, int]], turns: int) -> set[tuple[int, int]]:
    if not shape:
        raise ValueError("Empty shape.")
    result = set(shape)
    for _ in range(turns % 4):
        result = {(-y, x) for x, y in result}
    min_x = min(x for x, _ in result)
    min_y = min(y for _, y in result)
    return {(x - min_x, y - min_y) for x, y in result}


def fits(shape: set[tuple[int, int]], origin: tuple[int, int], turns: int,
         occupied: set[tuple[int, int]], width: int = 6, height: int = 5) -> bool:
    cells = {(x + origin[0], y + origin[1]) for x, y in normalized_rotate(shape, turns)}
    return all(0 <= x < width and 0 <= y < height for x, y in cells) and not (cells & occupied)


class LandChecks(unittest.TestCase):
    def test_exact_table(self):
        for area, protection, paid, dormant, tax, inflow in [
            (64, 0, 0, 0, 0, 10), (80, 0, 16, 0, 1.6, 8.4),
            (96, 0, 24, 8, 2.4, 7.6), (96, 16, 16, 0, 1.6, 8.4),
            (96, 32, 0, 0, 0, 10), (128, 0, 24, 40, 2.4, 7.6)]:
            with self.subTest(area=area, protection=protection):
                r = land_ledger(area, protection)
                self.assertEqual((r['paid'], r['dormant']), (paid, dormant))
                self.assertAlmostEqual(r['maintenance'], tax)
                self.assertAlmostEqual(r['inflow'], inflow)
    def test_exhaustive_small_nonnegative_and_conservation(self):
        for area in range(129):
            for protection in (0, 16, 32, 160):
                for seep in (0.0, 0.05, 1.0, 10.0):
                    r = land_ledger(area, protection, seep)
                    self.assertEqual(r['free'] + r['paid'] + r['dormant'], area)
                    self.assertGreaterEqual(r['inflow'], -1e-9)
                    self.assertLessEqual(r['maintenance'], seep + 1e-9)
    def test_zero_tax(self):
        r = land_ledger(128, seep=0, tax=0)
        self.assertEqual(r['dormant'], 0)
        self.assertEqual(r['maintenance'], 0)
    def test_zero_area_and_zero_source(self):
        self.assertEqual(land_ledger(0, seep=0)['inflow'], 0)
        self.assertEqual(land_ledger(96, seep=0)['dormant'], 32)
    def test_protection_does_not_generate_source_energy(self):
        self.assertEqual(land_ledger(64, protection=1000)['inflow'], 10)
    def test_partial_coverage(self):
        self.assertAlmostEqual(land_efficiency(0), 0.35)
        self.assertAlmostEqual(land_efficiency(0.5), 0.675)
        self.assertAlmostEqual(land_efficiency(1), 1.0)
    def test_insensitive_facility_and_visual_independent(self):
        self.assertEqual(land_efficiency(0, sensitivity=0), 1)
        self.assertEqual(land_efficiency(0, floor=1), 1)
    def test_negative_input_rejected(self):
        with self.assertRaises(ValueError): land_ledger(-1)


class EnergyChecks(unittest.TestCase):
    def test_condensation_base(self):
        c = CFG['condensation']
        raw = c['stone_energy_qi'] / c['conversion_efficiency'] * c['base_stones_per_minute']
        self.assertAlmostEqual(raw, 2.0)
        self.assertAlmostEqual(raw + c['active_overhead_qi_per_minute'], 2.1)
    def test_condensation_bonus_is_not_free_energy(self):
        c = CFG['condensation']
        nu = c['base_stones_per_minute'] * 1.4
        raw = c['stone_energy_qi'] / c['conversion_efficiency'] * nu
        self.assertAlmostEqual(nu, 0.252)
        self.assertAlmostEqual(raw, 2.8)
        self.assertGreater(raw, nu * c['stone_energy_qi'])
    def test_split_land_cost_across_springs(self):
        rates, total_tax = [10.0, 5.0], 2.4
        inflows = [s - total_tax * s / sum(rates) for s in rates]
        self.assertAlmostEqual(sum(inflows), sum(rates) - total_tax)
    def test_empty_pool_supply_bound(self):
        dt, x, inflow, draw_cap = 1/60, 0, 7.6, 12
        actual = min(draw_cap, x/dt+inflow)
        self.assertAlmostEqual(actual, 7.6)
        self.assertGreaterEqual(x + (inflow-actual)*dt, 0)
    def test_energy_loss_identity(self):
        # Over ten minutes, condensed stored energy + conversion loss + overhead = withdrawal.
        duration, raw, eta, overhead = 10, 2, 0.9, 0.1
        self.assertAlmostEqual(raw*duration*eta + raw*duration*(1-eta) + overhead*duration,
                               (raw+overhead)*duration)


class FormationChecks(unittest.TestCase):
    def test_capacity_table(self):
        self.assertEqual([world_capacity(r, 100) for r in range(1,5)], [6,9,12,15])
    def test_rank_one_example(self):
        self.assertEqual(world_capacity(1,0), 2)
        self.assertEqual(world_capacity(1,2), 4)
        self.assertEqual(2 + 1 + 1, world_capacity(1,2))
    def test_rank_zero_and_hard_cap(self):
        self.assertEqual(world_capacity(0,100), 0)
        self.assertEqual(world_capacity(100,1000), 16)
    def test_effect_saturation(self):
        self.assertAlmostEqual(formation_bonus(0.5,0.5,0.5),0.5)
        self.assertAlmostEqual(formation_bonus(50,0.5,0.5),0.5)
        self.assertEqual(formation_bonus(0,0.5,0.5),0)
    def test_overlap_receiver_hard_cap(self):
        self.assertAlmostEqual(stacked_bonus([0.4,0.4],0.4),0.4)
        self.assertAlmostEqual(stacked_bonus([0.2,0.2],0.4),0.4)
    def test_geometry_area(self):
        self.assertEqual(triangle_area([(0,0),(6,0),(0,4)]),12)
        self.assertEqual(triangle_area([(0,0),(0,6),(-4,0)]),12)
        self.assertEqual(triangle_area([(0,0),(1,1),(2,2)]),0)
    def test_work_is_integrated_not_harvest_snapshot(self):
        self.assertEqual(5*1 + 5*1.4,12)
        self.assertNotEqual(5*1 + 5*1.4,10*1.4)


class BeastAndStockChecks(unittest.TestCase):
    def test_chase_examples(self):
        self.assertAlmostEqual(chase_mean_multiplier(4,6,20),4/3)
        self.assertAlmostEqual(chase_mean_multiplier(2,6,40),1.125)
    def test_water_service_capacity(self):
        self.assertAlmostEqual(0.25*min(1,6/6),0.25)
        self.assertAlmostEqual(0.25*min(1,6/12),0.125)
    def test_same_type_trail_not_added(self):
        self.assertEqual(max(0.5,0.5),0.5)
        self.assertAlmostEqual(min(0.75,0.25+max(0.5,0.5)),0.75)
    def test_periodic_phase_and_partition(self):
        p, on = 40/60, 30/60
        self.assertAlmostEqual(periodic_on_duration(0,40/60,p,on),0.5)
        for start, middle, end in [(0,0.3,10),(1.21,2.74,600),(0,0.1,0.2)]:
            whole = periodic_on_duration(start,end,p,on)
            parts = periodic_on_duration(start,middle,p,on)+periodic_on_duration(middle,end,p,on)
            self.assertAlmostEqual(whole,parts)
    def test_periodic_continuous_refresh(self):
        self.assertAlmostEqual(periodic_on_duration(2,12,20/60,30/60),10)
    def test_stock_hysteresis(self):
        self.assertTrue(stock_state(False,6,6,6,12))
        self.assertFalse(stock_state(True,12,12,6,12))
        self.assertTrue(stock_state(True,8,8,6,12))
        self.assertFalse(stock_state(False,8,8,6,12))
    def test_reserved_output_does_not_create_redundant_job(self):
        self.assertFalse(stock_state(False,5,12,6,12))
    def test_replenishment_gross_and_net(self):
        mu, demand = 1/2.5, 3/12
        self.assertAlmostEqual(3/mu,7.5)
        self.assertAlmostEqual(3/(mu-demand),20)
    def test_research_work_values(self):
        self.assertEqual(2*1.5**0,2)
        self.assertAlmostEqual(2*1.5**4,10.125)


class RecipeClosureChecks(unittest.TestCase):
    def test_unbuffed_field_cycle(self):
        f = CFG['farming']
        cycle = (f['sow_work_required']+f['harvest_work_required'])/f['sow_harvest_work_per_minute'] + f['growth_work_required']/f['natural_growth_work_per_minute']
        self.assertAlmostEqual(cycle,4.2)
        self.assertAlmostEqual(f['harvest_herbs']/cycle,10/21)
    def test_two_fields_supply_one_potion_bench(self):
        output_per_field = 2/4.2
        demand = 2/2.5
        self.assertLess(output_per_field,demand)
        self.assertGreaterEqual(2*output_per_field,demand)
    def test_water_only_affects_growth_stage(self):
        cycle = 0.1 + 4/1.25 + 0.1
        self.assertAlmostEqual(cycle,3.4)
        self.assertNotAlmostEqual(2/cycle,(2/4.2)*1.25)
    def test_local_buffer_runtime(self):
        self.assertAlmostEqual((32/2)*4.2,67.2)
        self.assertAlmostEqual((32/2)*3.4,54.4)
    def test_config_guardrails(self):
        self.assertEqual(CFG['land']['base_free_cells'],64)
        self.assertLessEqual(CFG['land']['initial_cells'],CFG['land']['base_free_cells'])
        self.assertLessEqual(CFG['land']['base_free_cells'],CFG['land']['hard_area_cap'])
        self.assertFalse(CFG['research']['consumes_sample'])
        self.assertFalse(CFG['loot']['auto_pack'])
        self.assertFalse(CFG['farming']['water_required_for_survival'])
        self.assertFalse(CFG['multiplayer']['capacity_scales_with_online_count'])


class InventoryChecks(unittest.TestCase):
    def test_rotate_four_times_invariant(self):
        shape = {(0,0),(0,1),(1,1)}
        self.assertEqual(normalized_rotate(shape,4),shape)
    def test_valid_placement_and_overlap(self):
        square = {(0,0),(1,0),(0,1),(1,1)}
        self.assertTrue(fits(square,(4,3),0,set()))
        self.assertFalse(fits(square,(5,4),0,set()))
        self.assertFalse(fits(square,(4,3),0,{(4,3)}))
    def test_area_is_not_sufficient(self):
        occupied = {(x,y) for x in range(6) for y in range(5) if (x+y)%2==0}
        square = {(0,0),(1,0),(0,1),(1,1)}
        self.assertGreaterEqual(30-len(occupied),len(square))
        self.assertFalse(any(fits(square,(x,y),r,occupied)
                             for x in range(6) for y in range(5) for r in range(4)))
    def test_overhead_full_blocks_even_with_free_bag(self):
        k, overhead_count, bag_free = 3, 3, 30
        can_acquire = overhead_count < k
        self.assertFalse(can_acquire)
        self.assertGreater(bag_free,0)
    def test_rarity_reveal_bounded(self):
        times = CFG['loot']['reveal_seconds_by_rarity']
        self.assertEqual(times,sorted(times))
        self.assertLessEqual(max(times),1.4)
    def test_carried_loss_set_includes_overhead(self):
        bag, overhead, equipment, world = {'b1'},{'h1'},{'e1'},{'w1'}
        loss = bag|overhead|equipment
        self.assertIn('h1',loss)
        self.assertFalse(loss&world)


if __name__ == '__main__':
    unittest.main(verbosity=2)
