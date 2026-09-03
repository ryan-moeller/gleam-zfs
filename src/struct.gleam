// Copyright (c) 2026 Ryan Moeller
// SPDX-License-Identifier: BSD-2-Clause

import gleam/bit_array
import gleam/int
import gleam/list
import gleam/result
import gleam/string

pub type StructStorage =
  BitArray

pub fn pad(buf: StructStorage, len: Int) -> StructStorage {
  bit_array.append(buf, <<0:unit(8)-size(len)>>)
}

pub type Field(field_t) {
  Field(id: field_t, size: Int)
  Union(variants: UnionVariants(field_t))
}

pub type StructT(field_t) =
  List(Field(field_t))

pub type UnionVariants(field_t) =
  List(StructT(field_t))

fn sizeof_union(variants: UnionVariants(field_t)) -> Int {
  let assert Ok(size) =
    variants
    |> list.map(sizeof_struct)
    |> list.max(int.compare)
  size
}

pub fn sizeof_struct(struct_t: StructT(field_t)) -> Int {
  list.fold(struct_t, 0, fn(acc, field) {
    case field {
      Field(_, size) -> {
        acc + size
      }
      Union(variants) -> {
        acc + sizeof_union(variants)
      }
    }
  })
}

type FieldLayout {
  FieldLayout(offset: Int, length: Int)
}

fn find_field(
  struct_t: StructT(field_t),
  field: field_t,
) -> Result(FieldLayout, Nil) {
  case
    list.fold_until(struct_t, #(False, FieldLayout(0, 0)), fn(prev, this) {
      let assert #(False, FieldLayout(prev_offset, prev_length)) = prev
      let next_offset = prev_offset + prev_length
      case this {
        Field(id, size) if id == field ->
          list.Stop(#(True, FieldLayout(next_offset, size)))
        Field(_, size) ->
          list.Continue(#(False, FieldLayout(next_offset, size)))
        Union(variants) ->
          case list.find_map(variants, find_field(_, field)) {
            Ok(FieldLayout(offset, size)) ->
              list.Stop(#(True, FieldLayout(next_offset + offset, size)))
            Error(Nil) ->
              list.Continue(#(
                False,
                FieldLayout(next_offset, sizeof_union(variants)),
              ))
          }
      }
    })
  {
    #(True, layout) -> Ok(layout)
    #(False, _) -> Error(Nil)
  }
}

fn struct_field(struct_t: StructT(field_t), field: field_t) -> FieldLayout {
  list.fold_until(struct_t, FieldLayout(0, 0), fn(prev, this) {
    let next_offset = prev.offset + prev.length
    case this {
      Field(id, size) if id == field -> list.Stop(FieldLayout(next_offset, size))
      Field(_, size) -> list.Continue(FieldLayout(next_offset, size))
      Union(variants) ->
        case list.find_map(variants, find_field(_, field)) {
          Ok(FieldLayout(offset, size)) ->
            list.Stop(FieldLayout(next_offset + offset, size))
          Error(Nil) ->
            list.Continue(FieldLayout(next_offset, sizeof_union(variants)))
        }
    }
  })
}

pub fn struct_read(
  struct_t: StructT(field_t),
  field: field_t,
  data: StructStorage,
) -> StructStorage {
  let layout = struct_field(struct_t, field)
  let assert Ok(value) = bit_array.slice(data, layout.offset, layout.length)
  value
}

pub type FieldValue(field_t) {
  FieldValue(id: field_t, value: StructStorage)
}

pub type Struct(field_t) =
  List(FieldValue(field_t))

fn find_value(
  values: Struct(field_t),
  id: field_t,
) -> Result(FieldValue(field_t), Nil) {
  list.find(values, fn(value) { value.id == id })
}

fn build_fields(
  init: StructStorage,
  fields: StructT(field_t),
  values: Struct(field_t),
) -> StructStorage {
  list.fold(fields, init, fn(buf, field) {
    case field {
      Field(field_id, size) ->
        case find_value(values, field_id) {
          Ok(FieldValue(_, value)) -> {
            assert bit_array.byte_size(value) == size
            bit_array.append(buf, value)
          }
          Error(Nil) -> pad(buf, size)
        }
      Union(variants) ->
        case
          list.find(variants, fn(variant) {
            list.any(values, fn(value) {
              list.any(variant, fn(variant_field) {
                case variant_field {
                  Field(field_id, _) -> field_id == value.id
                  Union(_) -> False
                }
              })
            })
          })
        {
          Ok(variant) -> build_fields(buf, variant, values)
          Error(Nil) -> pad(buf, sizeof_union(variants))
        }
    }
  })
}

pub fn build_struct(
  struct_t: StructT(field_t),
  values: Struct(field_t),
) -> StructStorage {
  build_fields(<<>>, struct_t, values)
}

pub fn int_uint8(x: Int) -> StructStorage {
  <<x:native-size(8)>>
}

pub fn int_int32(x: Int) -> StructStorage {
  <<x:native-size(32)>>
}

pub fn int_uint32(x: Int) -> StructStorage {
  <<x:native-size(32)>>
}

pub fn int_uint64(x: Int) -> StructStorage {
  <<x:native-size(64)>>
}

pub fn uint64_int(bin: StructStorage) -> Result(Int, Nil) {
  case bin {
    <<val:native-unsigned-size(64)>> -> Ok(val)
    _ -> Error(Nil)
  }
}

pub fn string_pad(
  struct_t: StructT(field_t),
  field: field_t,
  s: String,
) -> Result(FieldValue(field_t), Nil) {
  let FieldLayout(_, length) = struct_field(struct_t, field)
  use value <- result.try(case length < string.byte_size(s) {
    True -> Error(Nil)
    False -> {
      let value = bit_array.from_string(s)
      Ok(pad(value, length - bit_array.byte_size(value)))
    }
  })
  Ok(FieldValue(field, value))
}
