import unittest

from app.lift_control import lift_height_action, with_direct_lift_velocity


class LiftHeightActionTest(unittest.TestCase):
    def test_uses_configured_step(self):
        self.assertEqual(
            lift_height_action({"u"}, 120.0, 10.0, 0.0, 600.0),
            {"lift_axis.height_mm": 130.0},
        )
        self.assertEqual(
            lift_height_action({"j"}, 120.0, 10.0, 0.0, 600.0),
            {"lift_axis.height_mm": 110.0},
        )

    def test_stops_when_released(self):
        self.assertEqual(
            lift_height_action(set(), 120.0, 10.0, 0.0, 600.0),
            {"lift_axis.height_mm": 120.0, "lift_axis.vel": 0},
        )

    def test_clamps_to_soft_limits(self):
        self.assertEqual(
            lift_height_action({"u"}, 597.0, 10.0, 0.0, 600.0),
            {"lift_axis.height_mm": 600.0},
        )
        self.assertEqual(
            lift_height_action({"j"}, 3.0, 10.0, 0.0, 600.0),
            {"lift_axis.height_mm": 0.0},
        )

    def test_opposite_keys_hold_position(self):
        self.assertEqual(
            lift_height_action({"u", "j"}, 120.0, 10.0, 0.0, 600.0),
            {"lift_axis.height_mm": 120.0},
        )

    def test_height_target_gets_direct_velocity_for_transport(self):
        recorded = {"lift_axis.height_mm": 130.0, "arm_joint.pos": 4.0}
        wire = with_direct_lift_velocity(recorded, 120.0, 1000)

        self.assertEqual(wire["lift_axis.vel"], 1000)
        self.assertNotIn("lift_axis.vel", recorded)
        self.assertEqual(wire["lift_axis.height_mm"], 130.0)

    def test_release_velocity_is_not_overridden(self):
        released = {"lift_axis.height_mm": 120.0, "lift_axis.vel": 0}
        self.assertEqual(with_direct_lift_velocity(released, 118.0, 1000), released)

    def test_down_target_gets_negative_velocity(self):
        wire = with_direct_lift_velocity({"lift_axis.height_mm": 110.0}, 120.0, 1000)
        self.assertEqual(wire["lift_axis.vel"], -1000)


if __name__ == "__main__":
    unittest.main()
