import gleam/bool
import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/pair
import gleam/result

type Value =
  Int

type Probability =
  Float

pub type UniformDamageRange {
  UniformDamageRange(min: Float, max: Float)
}

pub fn scale_range(
  range: UniformDamageRange,
  by factor: Float,
) -> UniformDamageRange {
  UniformDamageRange(min: range.min *. factor, max: range.max *. factor)
}

pub fn range_to_pmf(range: UniformDamageRange) -> Pmf {
  let total_mass = range.max -. range.min
  mass_points_([], float.truncate(range.min), range.min, range.max)
  |> list.map(pair.map_second(_, fn(mass) { mass /. total_mass }))
  |> dict.from_list()
  |> Pmf()
}

fn mass_points_(
  acc: List(MassPoint),
  bin_label: Int,
  min: Float,
  max: Float,
) -> List(MassPoint) {
  assert min <. max
  case int.to_float(bin_label) {
    x if x >=. max -> acc
    x if min -. x >. 1.0 -> mass_points_(acc, float.truncate(min), min, max)
    x -> {
      let bin_mass = float.min(x +. 1.0, max) -. float.max(x, min -. x)
      mass_points_([#(bin_label, bin_mass), ..acc], bin_label + 1, min, max)
    }
  }
}

// Value simulation
pub type Pmf {
  Pmf(dict.Dict(Value, Probability))
  // TruncatedPmf(dict.Dict(Value, Float))
}

type MassPoint =
  #(Value, Probability)

fn clamp_probability(p: Float) -> Probability {
  p |> float.max(0.0) |> float.min(1.0)
}

pub fn uniform_pmf(bound_1: Value, bound_2: Value) -> Pmf {
  let values = case bound_1 <= bound_2 {
    True -> new_list_of_ints(from: bound_1, to: bound_2)
    False -> new_list_of_ints(from: bound_2, to: bound_1)
  }
  let p = 1.0 /. int.to_float(list.length(values))
  values |> list.map(fn(v) { #(v, p) }) |> dict.from_list() |> Pmf()
}

fn new_list_of_ints(from start: Int, to end: Int) -> List(Int) {
  case start <= end {
    True -> new_list_of_ints_([start], from: start, to: end)
    False -> []
  }
}

fn new_list_of_ints_(
  acc acc: List(Int),
  from start: Int,
  to end: Int,
) -> List(Int) {
  assert start <= end
  case start == end {
    True -> list.reverse(acc)
    False -> new_list_of_ints_([start + 1, ..acc], from: start + 1, to: end)
  }
}

pub fn get_probability(pmf: Pmf, value: Value) -> Probability {
  raw(pmf) |> dict.get(value) |> result.unwrap(0.0)
}

pub fn get_max_value(pmf: Pmf) -> Value {
  // Unwrap should never trigger on well-formed pmf,
  // so set an "obviously wrong" result inside it as a smoke alarm
  raw(pmf) |> dict.keys() |> list.max(int.compare) |> result.unwrap(-999)
}

pub fn get_nonzero_min_value(pmf: Pmf) -> Value {
  raw(pmf)
  |> dict.keys()
  |> list.filter(fn(k) { k != 0 })
  |> list.max(order.reverse(int.compare))
  |> result.unwrap(999)
}

fn raw(pmf: Pmf) -> dict.Dict(Value, Probability) {
  case pmf {
    Pmf(pmf) -> pmf
  }
}

pub fn scale_pmf_values(pmf: Pmf, by factor: Float) -> Pmf {
  raw(pmf)
  |> dict.to_list()
  |> list.map(fn(x) {
    let #(v, p) = x
    let new_v = int.to_float(v) *. factor |> float.round()
    #(new_v, p)
  })
  |> dict.from_list()
  |> Pmf()
}

fn scale_pmf(pmf: Pmf, by factor: Float) -> Pmf {
  raw(pmf)
  |> dict.map_values(fn(_, p) { p *. factor })
  |> Pmf()
}

/// Scales the probability values by `factor` clamped to `[0;1]`
/// and reassigns excess probability to `value` to preserve normalisation.
pub fn scale_and_reassign_probability(
  pmf: Pmf,
  by factor: Probability,
  reassign_to value: Value,
) -> Pmf {
  let pmf = pmf |> scale_pmf(by: clamp_probability(factor))
  let after_sum_other_ps =
    raw(pmf)
    |> dict.delete(value)
    |> dict.to_list()
    |> list.fold(from: 0.0, with: fn(acc: Probability, mp: MassPoint) {
      acc +. pair.second(mp)
    })
  raw(pmf)
  |> dict.insert(value, 1.0 -. after_sum_other_ps)
  |> dict.filter(fn(_, p) { p >=. 0.0 })
  |> Pmf()
}

/// Add two distributions together, maintaining normalisation.
pub fn add_pmfs(pmf1: Pmf, w1: Probability, pmf2: Pmf) -> Pmf {
  let w1 = clamp_probability(w1)
  let pmf1 = scale_pmf(pmf1, w1) |> raw()
  let pmf2 = scale_pmf(pmf2, 1.0 -. w1) |> raw()
  dict.combine(pmf1, pmf2, float.add) |> Pmf()
}

/// Multiply two distributions together, as though making one after the other.
pub fn multiply_pmfs(pmf1: Pmf, pmf2: Pmf) -> Pmf {
  let pmf1 = raw(pmf1)
  let pmf2 = raw(pmf2)
  dict.fold(
    over: pmf1,
    from: dict.new(),
    with: fn(acc1, v1: Value, p1: Probability) {
      dict.fold(
        over: pmf2,
        from: dict.new(),
        with: fn(acc2, v2: Value, p2: Probability) {
          dict.upsert(acc2, int.add(v1, v2), fn(p) {
            p |> option.unwrap(0.0) |> float.add(p1 *. p2)
          })
        },
      )
      |> dict.combine(acc1, float.add)
    },
  )
  |> Pmf()
}

pub fn expected_rolls_to_exceed_total_k(
  k: Int,
  pmf: Pmf,
) -> Result(Float, Nil) {
  // If our PMF is guaranteed to hit 0 (or less, technically), expected rolls is infinite
  let p_0 = get_probability(pmf, 0)
  use <- bool.guard(
    when: float.loosely_equals(p_0, 1.0, tolerating: 0.01),
    return: Error(Nil),
  )

  // Let E_k(n) be the expected rolls needed to exceed k with a max hit of n.
  let n = get_max_value(pmf)
  // Then E_k(n) = 1 + \sum_{i=0}^{n} (p_i * E_{k-i}(n)).
  // That expression says:
  // "the expected number of rolls is 1 (make one roll),
  // plus the probability-weighted average of the expected rolls
  // needed to exceed whatever new k was left after each possible roll outcome i.
  // (Including 0, which is a miss.)"

  // Note that in the case of a miss (i = 0), E_k(n) appears on both sides of the equation.
  // Rearranging to get E_k(n) in terms of other E_m(n) with m < k:
  // E_k(n) = (1 / (1 - p_0)) * (1 + \sum_{i=1}^{n} (p_i * E_{k-i}(n)))

  // To solve this, we can use dynamic programming to get a lookup for the E_k(n) values.
  // (The boundary conditions of the problem are given in the lookup function.)
  let lookups = generate_e_j_values(pmf, dict.new(), k:, p_0:, n:)

  // Once we have all the E_k(n) values we need, finish the calculation.
  calculate_e_j_n(pmf, lookups, p_0:, k:, n:)
  |> result.replace_error(Nil)
}

type Memo =
  dict.Dict(Int, Float)

type PIdxAndEKIdx {
  PIdxAndEKIdx(#(Int, Float))
}

// This function should only be called once we know all the E_k values we need.
fn calculate_e_j_n(
  pmf: Pmf,
  known_e_k_values: dict.Dict(Int, Float),
  p_0 p_0: Float,
  k k: Int,
  n n: Int,
) -> Result(Float, Value) {
  new_list_of_ints(1, n + 1)
  |> list.map(fn(i) {
    let p_i = get_probability(pmf, i)
    use e_k_minus_i <- result.map(lookup_e_j(k - i, p_0, known_e_k_values))
    // should never be Error if our lookup calculation was complete
    p_i *. e_k_minus_i
  })
  |> result.all()
  |> result.map(float.sum)
  |> result.map(fn(x) { { 1.0 +. x } /. { 1.0 -. p_0 } })
}

fn generate_e_j_values(
  pmf: Pmf,
  known_e_j_values: dict.Dict(Int, Float),
  k k: Int,
  p_0 p_0: Probability,
  n n: Int,
) -> dict.Dict(Int, Float) {
  // The lookup checks if E_k is known for the current k,
  // either through boundary conditions or a direct lookup.
  case lookup_e_j(k, p_0, known_e_j_values) {
    // If E_k is known, we are done.
    Ok(_) -> known_e_j_values
    // Else, we need to generate E_k.
    Error(_) -> {
      // By the recurrence relation, we might need a whole bunch of E_j
      // for other values of j.
      let unknown_js =
        new_list_of_ints(1, n + 1)
        |> list.map(fn(i) { lookup_e_j(k - i, p_0, known_e_j_values) })
        |> result.partition()
        |> pair.second()

      // If there are any unknown E_j values, calculate them recursively.
      let new_calculated_e_js = case unknown_js {
        [] -> dict.new()
        unknown_js -> {
          list.fold(over: unknown_js, from: known_e_j_values, with: fn(acc, j) {
            generate_e_j_values(pmf, acc, k: j, p_0:, n:)
          })
        }
      }
      let known_e_j_values = known_e_j_values |> dict.merge(new_calculated_e_js)
      // Once we know all the needed E_j values,
      // we can calculate the current one and add it to our known ones.
      let e_k =
        calculate_e_j_n(pmf, known_e_j_values, p_0:, k:, n:)
        |> result.unwrap(-9999.0)
      known_e_j_values |> dict.insert(k, e_k)
    }
  }
}

fn lookup_e_j(
  j: Int,
  p_0: Probability,
  known_e_j_values: dict.Dict(Int, Float),
) -> Result(Float, Int) {
  // The boundary conditions of the problem give us some base cases of E_k(n).
  case j {
    // If our target k is less than zero, we are done, no rolls needed.
    j if j <= 0 -> Ok(0.0)
    // If our target is one, then it simply depends on whether we hit or not:
    // E_1(n) = E_1(1) = 1 + p_0 * E_1(1)
    // Solving, E_1(1) = 1 / (1 - p_0)
    1 -> Ok(1.0 /. { 1.0 -. p_0 })
    // Else, we need to look up our memoized E_k values.
    j -> dict.get(known_e_j_values, j) |> result.map_error(fn(_) { j })
  }
}

// A version of the same calculation avoiding incomplete lookups.
// Possibly harder to read, but safer (no unexpected dictionary lookup failures).
pub fn trickier_expected_rolls_to_exceed_total_k(
  k: Int,
  pmf: Pmf,
) -> Result(Float, Nil) {
  let p_0 = get_probability(pmf, 0)
  let n = get_max_value(pmf)
  case float.loosely_equals(p_0, 1.0, tolerating: 0.01) {
    True -> Error(Nil)
    False -> recurse(pmf, dict.new(), k:, p_0:, n:) |> pair.first() |> Ok()
  }
}

fn recurse(
  pmf: Pmf,
  known_e_k_values: Memo,
  k k: Int,
  p_0 p_0: Probability,
  n n: Int,
) -> #(Float, Memo) {
  // The lookup checks if E_k is known for the current k,
  // either through boundary conditions or a direct lookup.
  case lookup_e_j(k, p_0, known_e_k_values) {
    // If E_k is known, we are done.
    Ok(e_k) -> #(e_k, known_e_k_values)
    // Else, we need to generate E_k.
    Error(_) -> {
      // By the recurrence relation, we might need a whole bunch of E_j
      // for other values of j.
      let #(knowns, unknown_ks): #(List(PIdxAndEKIdx), List(#(Int, Int))) = {
        new_list_of_ints(1, n + 1)
        |> list.map(fn(i) {
          let v = k - i
          lookup_e_j(v, p_0, known_e_k_values)
          |> result.map(fn(e_v: Float) { #(i, e_v) |> PIdxAndEKIdx() })
          |> result.map_error(fn(_) { #(i, k - i) })
        })
        |> result.partition()
      }

      // If there are any E_j values we don't know, calculate them recursively.
      let #(calculated_unknowns, d) = case unknown_ks {
        [] -> #([], known_e_k_values)
        unknown_ks -> {
          list.fold(
            over: unknown_ks,
            from: #([], known_e_k_values),
            with: fn(
              acc: #(List(PIdxAndEKIdx), Memo),
              p_index_and_e_index: #(Int, Int),
            ) {
              let #(acc_known_pairs, acc_known_e_k_values) = acc
              let #(i, v) = p_index_and_e_index
              let #(e_v, memo) =
                recurse(pmf, acc_known_e_k_values, k: v, p_0:, n:)
              #([PIdxAndEKIdx(#(i, e_v)), ..acc_known_pairs], memo)
            },
          )
        }
      }
      let e_k =
        knowns
        |> list.append(calculated_unknowns)
        |> list.map(fn(tup) {
          let PIdxAndEKIdx(#(i, e_k_minus_i)) = tup
          let p_i = get_probability(pmf, i)
          p_i *. e_k_minus_i
        })
        |> float.sum()
        |> fn(x) { { 1.0 +. x } /. { 1.0 -. p_0 } }
      #(e_k, d |> dict.insert(k, e_k))
    }
  }
}
