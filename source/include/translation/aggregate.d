/**
   Translate aggregates
 */
module include.translation.aggregate;

import include.from;

/**
   Structs can be anomymous in C, and it's even common
   to typedef them to a name. We come up with new names
   that we track here so as to be able to properly transate
   those typedefs.
 */
private shared string[from!"clang.c.index".CXCursor] gNicknames;


string[] translateStruct(in from!"clang".Cursor cursor,
                         in from!"include.runtime.options".Options options =
                                from!"include.runtime.options".Options())
    @safe
{
    import clang: Cursor;
    assert(cursor.kind == Cursor.Kind.StructDecl);
    return translateAggregate(options, cursor, "struct");
}

string[] translateUnion(in from!"clang".Cursor cursor,
                        in from!"include.runtime.options".Options options =
                               from!"include.runtime.options".Options())
    @safe
{
    import clang: Cursor;
    assert(cursor.kind == Cursor.Kind.UnionDecl);
    return translateAggregate(options, cursor, "union");
}

string[] translateEnum(in from!"clang".Cursor cursor,
                       in from!"include.runtime.options".Options options =
                              from!"include.runtime.options".Options())
    @safe
{
    import clang: Cursor;
    import std.typecons: nullable;

    assert(cursor.kind == Cursor.Kind.EnumDecl);

    // Translate it twice so that C semantics are the same (global names)
    // but also have a named version for optional type correctness and
    // reflection capabilities.
    // This means that `enum Foo { foo, bar }` in C will become:
    // `enum Foo { foo, bar }` _and_ `enum { foo, bar }` in D.
    return
        translateAggregate(options, cursor, "enum") ~
        translateAggregate(options, cursor, "enum", nullable(""));
}

// not pure due to Cursor.opApply not being pure
string[] translateAggregate(
    in from!"include.runtime.options".Options options,
    in from!"clang".Cursor cursor,
    in string keyword,
    in from!"std.typecons".Nullable!string spelling = from!"std.typecons".Nullable!string()
)
    @safe
{
    import include.translation.unit: translate;
    import clang: Cursor;
    import std.algorithm: map;
    import std.array: array;

    // Avoid forward declarations. Not sure if this is the right way.
    if(cursor.children.length == 0) return [];

    string[] lines;

    const name = spelling.isNull ? spellingOrNickname(cursor) : spelling.get;

    lines ~= keyword ~ ` ` ~ name;
    lines ~= `{`;

    foreach(member; cursor) {
        lines ~= translate(member, options.indent).map!(a => "    " ~ a).array;
    }

    lines ~= `}`;

    return lines;
}


string[] translateField(in from!"clang".Cursor field,
                        in from!"include.runtime.options".Options options =
                               from!"include.runtime.options".Options()
                        )
    @safe pure
{

    import include.translation.type: translate;
    import clang: Cursor;
    import std.conv: text;

    assert(field.kind == Cursor.Kind.FieldDecl,
           text("Field of wrong kind: ", field));

    return [text(translate(field.type, options), " ", field.spelling, ";")];
}

// return the spelling if it exists, or our made-up nickname for it
// if not
package string spellingOrNickname(in from!"clang".Cursor cursor) @safe {

    import std.conv: text;

    static int index;

    if(cursor.spelling != "") return cursor.spelling;

    if(cursor.cx !in gNicknames) {
        gNicknames[cursor.cx] = text("_Anonymous_", index++);
    }

    return gNicknames[cursor.cx];
}
