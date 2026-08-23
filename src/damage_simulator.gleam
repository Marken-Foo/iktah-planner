import gleam/float
import gleam/int
import gleam/result
import lustre/effect

import probability as probs

pub type Model {
  Model(
    player_atk: Int,
    player_str: Int,
    player_crit_chance: Float,
    mob_def: Int,
    mob_hp: Int,
    weapon_time_per_hit_input: String,
    weapon_time_per_hit: Float,
  )
}

pub type Message {
  UserSetPlayerAtk(String)
  UserSetPlayerStr(String)
  UserSetPlayerCritChance(String)
  UserSetMobDef(String)
  UserSetMobHp(String)
  UserSetWeaponSpeed(String)
}

pub fn init(_) -> #(Model, effect.Effect(Message)) {
  Model(
    player_atk: 1,
    player_str: 1,
    mob_def: 1,
    mob_hp: 120,
    player_crit_chance: 0.05,
    weapon_time_per_hit_input: "2.0",
    weapon_time_per_hit: 2.0,
  )
  |> fn(m) { #(m, effect.none()) }
}

pub fn update(
  model: Model,
  message: Message,
) -> #(Model, effect.Effect(Message)) {
  case message {
    UserSetPlayerAtk(str) -> {
      let player_atk = int.parse(str) |> result.unwrap(model.player_atk)
      model
      |> fn(m) { Model(..m, player_atk:) }
      |> fn(m) { #(m, effect.none()) }
    }
    UserSetPlayerStr(str) -> {
      let player_str = int.parse(str) |> result.unwrap(model.player_str)
      model
      |> fn(m) { Model(..m, player_str:) }
      |> fn(m) { #(m, effect.none()) }
    }
    UserSetPlayerCritChance(str) -> {
      let player_crit_chance =
        int.parse(str)
        |> result.map(int.to_float)
        |> result.try(float.divide(_, by: 100.0))
        |> result.unwrap(model.player_crit_chance)
      model
      |> fn(m) { Model(..m, player_crit_chance:) }
      |> fn(m) { #(m, effect.none()) }
    }
    UserSetMobDef(str) -> {
      let mob_def = int.parse(str) |> result.unwrap(model.mob_def)
      model
      |> fn(m) { Model(..m, mob_def:) }
      |> fn(m) { #(m, effect.none()) }
    }
    UserSetMobHp(str) -> {
      let mob_hp = int.parse(str) |> result.unwrap(model.mob_hp)
      model
      |> fn(m) { Model(..m, mob_hp:) }
      |> fn(m) { #(m, effect.none()) }
    }
    UserSetWeaponSpeed(str) -> {
      let weapon_time_per_hit =
        float.parse(str)
        |> result.try_recover(fn(_) {
          int.parse(str) |> result.map(int.to_float)
        })
        |> result.unwrap(model.weapon_time_per_hit)
      model
      |> fn(m) {
        Model(..m, weapon_time_per_hit_input: str, weapon_time_per_hit:)
      }
      |> fn(m) { #(m, effect.none()) }
    }
  }
}

type Damage =
  Int

type Probability =
  Float

fn clamp_probability(p: Float) -> Probability {
  p |> float.max(0.0) |> float.min(1.0)
}

pub fn chance_to_hit(
  player_atk player_atk: Int,
  mob_def mob_def: Int,
) -> Probability {
  { 50.0 +. 0.75 *. int.to_float(player_atk - mob_def) }
  |> fn(p) { p /. 100.0 }
  |> clamp_probability()
}

pub fn max_hit(player_str: Int) -> Damage {
  1 + player_str / 3
}

fn apply_crit_rolls(
  base_pmf: probs.Pmf,
  player_crit_chance: Float,
) -> probs.Pmf {
  // Roll twice
  let crit_pmf = probs.multiply_pmfs(base_pmf, base_pmf)
  // On a given hit, chance of p to crit and 1-p to not crit
  probs.add_pmfs(crit_pmf, clamp_probability(player_crit_chance), base_pmf)
}

fn apply_miss_chance(
  base_pmf: probs.Pmf,
  chance_to_hit: Probability,
) -> probs.Pmf {
  base_pmf |> probs.scale_and_reassign_probability(chance_to_hit, 0)
}

pub fn hits_per_kill(
  player_atk player_atk: Int,
  player_str player_str: Int,
  mob_def mob_def: Int,
  mob_hp mob_hp: Int,
  player_crit_chance player_crit_chance: Float,
) -> Result(Float, Nil) {
  let pmf_of_one_attack =
    probs.uniform_pmf(1, max_hit(player_str))
    |> apply_miss_chance(chance_to_hit(player_atk, mob_def))
    |> apply_crit_rolls(player_crit_chance)
  probs.expected_rolls_to_exceed_total_k(mob_hp, pmf_of_one_attack)
}
