--  BESM2_Fmt.Entities - typed domain records for a BESM entity
--  (character/template/item), built by walking a Libfyaml.Nodes.Node
--  once via Load_Entity.
--
--  Unlike besm2-rst.scm, which re-walks the raw alist on every access
--  and separately in each of its four process-entity-* backends, this
--  decodes each entity exactly once into plain Ada values. That
--  includes work that's format-independent in the Scheme too (every
--  backend calls the same make-attribute-details and sorts attributes/
--  defects/skills the same way) -- computed here, once, rather than
--  repeated per backend.

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Libfyaml.Nodes;

package BESM2_Fmt.Entities is

   package String_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Unbounded_String);

   type Stat is record
      Name   : Unbounded_String;
      Value  : Unbounded_String;
      Points : Integer;
   end record;

   package Stat_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Stat);

   type Derived_Value is record
      Name         : Unbounded_String;
      Value        : Unbounded_String;
      Alternatives : String_Vectors.Vector;  -- empty = none
   end record;

   package Derived_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Derived_Value);

   type Attribute is record
      Name    : Unbounded_String;
      --  Already includes the "(effective)" suffix when present (see
      --  besm2-rst.scm's process-attribute: this combining is
      --  identical in all four output backends, so it's done once
      --  here rather than in each). Empty if the attribute has no
      --  level (e.g. some mecha sub-attributes).
      Level   : Unbounded_String;
      Points  : Integer;
      --  From make-attribute-details: elements, enhancements/limiters,
      --  and the free-text "details" field, already combined and
      --  joined. Empty means "no details" (make-attribute-details
      --  never yields a present-but-empty result -- see its Ada port
      --  in the body).
      Details : Unbounded_String;
   end record;

   package Attribute_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Attribute);

   type Defect is record
      Name    : Unbounded_String;
      Points  : Integer;
      Details : Unbounded_String;  -- trimmed "details" text; empty = none
   end record;

   package Defect_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Defect);

   type Skill is record
      Name            : Unbounded_String;
      Level           : Unbounded_String;
      Points          : Integer;
      Specialisations : String_Vectors.Vector;  -- empty = none
   end record;

   package Skill_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Skill);

   type Entity is record
      Has_Name        : Boolean := False;
      Name            : Unbounded_String;
      Has_Tagline     : Boolean := False;
      Tagline         : Unbounded_String;
      Has_Description : Boolean := False;
      Description     : Unbounded_String;
      Has_Size        : Boolean := False;
      Size            : Unbounded_String;

      --  Has_Key (entity, "mecha") -- presence, not value: matches
      --  besm2-rst.scm's `(assoc "mecha" entity)` used directly as a
      --  boolean, which is truthy on presence regardless of the YAML
      --  value. See PLAN.md's open question on this; ported faithfully
      --  for now.
      Mecha : Boolean := False;

      --  Stats/Derived are kept in document order (the Scheme never
      --  sorts them). Attributes/Defects/Skills are sorted
      --  case-insensitively by name, matching every one of the
      --  Scheme's four backends doing `(sort xs name-ci<?)` alike.
      Stats      : Stat_Vectors.Vector;
      Derived    : Derived_Vectors.Vector;
      Attributes : Attribute_Vectors.Vector;
      Defects    : Defect_Vectors.Vector;
      Skills     : Skill_Vectors.Vector;

      Stats_Total      : Integer := 0;
      Attributes_Total : Integer := 0;
      Defects_Total    : Integer := 0;
      --  Not included in Entity_Total -- matches the Scheme, which
      --  never adds skill points into the entity total.
      Skills_Total     : Integer := 0;
      Entity_Total     : Integer := 0;
   end record;

   function Load_Entity (N : Libfyaml.Nodes.Node) return Entity
     with Pre => N.Is_Valid and then N.Is_Mapping;

   function Join (Vec : String_Vectors.Vector; Sep : String) return String;
   --  "" for an empty Vec. Exposed for format backends joining
   --  Alternatives/Specialisations the same way besm2-rst.scm does at
   --  display time in each (e.g. process-derived-terse,
   --  process-skill-terse).

end BESM2_Fmt.Entities;
