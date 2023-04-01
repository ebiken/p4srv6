# p4srv6 design

- [P4 code](#p4-code)
  - [P4 header and metadata naming schema](#p4-header-and-metadata-naming-schema)


## P4 code

### P4 header and metadata naming schema

Header and metadata naming were decided considering below reference codes available in public.

- use snake_case (and not CamelCase)
  - e.g. `ipv4_h`, `vlan_tag_h`
- end with `_h` for headers and `_t` for types
  - e.g. `header ethernet_h`, `typedef bit<48> mac_addr_t;`
- use all capital for costants
  - e.g. `const bit<16> ETHERTYPE_IPV4 = 0x0800;`

References when considering P4 naming schema.

- [Portable P4 Headers (PPH)](https://docs.google.com/document/d/16IGRYi3WyEGZIXeT8bPOZ4DmcCs292EVuCJ_0WWfsHQ/edit#heading=h.whlhh81fobyp)
  - There was a discussion to standardize, within the P4 community, header definitions for some of the most common headers specified in public RFC and IEEE specifications.
  - The discussion was started around April 2021 with some comments (in google docs), but was not concluded.
- P4 example code in p4-spec repo
  - https://github.com/p4lang/p4-spec/tree/main/p4-16/discussions
  - There are a few P4 example code in this repo.
- IPDK simple_l3 example
  - [simple_l3.p4](https://github.com/ipdk-io/ipdk/tree/main/build/networking/examples/simple_l3)

