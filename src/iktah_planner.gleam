import lustre

import damage_simulator as dmgsim

pub fn main() -> Nil {
  let app = lustre.application(dmgsim.init, dmgsim.update, dmgsim.view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}
