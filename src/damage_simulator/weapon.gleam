pub type ConsumedLog {
  None
  Hemlock
  RedFir
  Oak
  Maple
  Cedar
  Elderwood
}

pub fn log_bonus(log: ConsumedLog) -> Float {
  case log {
    None -> 0.0
    Hemlock -> 0.05
    RedFir -> 0.1
    Oak -> 0.2
    Maple -> 0.3
    Cedar -> 0.4
    Elderwood -> 0.5
  }
}

pub type Weapon {
  Weapon(id: String, name: String, atk: Int, str: Int, time_per_hit: Float)
  Arborbiter(
    id: String,
    name: String,
    atk: Int,
    str: Int,
    time_per_hit: Float,
    consumed_log: ConsumedLog,
  )
}

pub fn by_id(name: String) -> Weapon {
  case name {
    "kings-klaws" ->
      Weapon(
        id: "kings-klaws",
        name: "King's Klaws",
        atk: 15,
        str: 10,
        time_per_hit: 2.0,
      )
    "arborbiter" ->
      Arborbiter(
        id: "arborbiter",
        name: "Arborbiter",
        atk: 35,
        str: 20,
        time_per_hit: 2.8,
        consumed_log: Elderwood,
      )
    "klynite-dagger" ->
      Weapon(
        id: "klynite-dagger",
        name: "Klynite Dagger",
        atk: 15,
        str: 14,
        time_per_hit: 2.4,
      )
    "alchemists-kris" ->
      Weapon(
        id: "alchemists-kris",
        name: "Alchemist's Kris",
        atk: 10,
        str: 5,
        time_per_hit: 2.2,
      )
    "shadow-dagger" ->
      Weapon(
        id: "shadow-dagger",
        name: "Shadow Dagger",
        atk: 20,
        str: 5,
        time_per_hit: 2.2,
      )
    _ -> Weapon(id: "none", name: "None", atk: 0, str: 0, time_per_hit: 3.0)
  }
}
