package kiss;

import haxe.macro.Expr;
import haxe.macro.Context;
import kiss.Reader;
import kiss.Types;
import kiss.Helpers;
import kiss.Stream;
import kiss.CompileError;

using kiss.Helpers;
using kiss.Reader;
using StringTools;

// Field forms convert Kiss reader expressions into Haxe macro class fields
typedef FieldFormFunction = (wholeExp:ReaderExp, args:Array<ReaderExp>, convert:ExprConversion) -> Field;

class FieldForms {
    public static function builtins() {
        var map:Map<String, FieldFormFunction> = [];

        map["defvar"] = varOrProperty.bind("defvar");
        map["defprop"] = varOrProperty.bind("defprop");

        map["defun"] = funcOrMethod.bind("defun");
        map["defmethod"] = funcOrMethod.bind("defmethod");

        return map;
    }

    static function fieldAccess(formName:String, fieldName:String) {
        var access = [];
        if (formName == "defvar" || formName == "defun") {
            access.push(AStatic);
        }
        access.push(if (fieldName.startsWith("_")) APrivate else APublic);
        return access;
    }

    static function fieldName(formName:String, nameExp:ReaderExp) {
        return switch (nameExp.def) {
            case Symbol(name) | TypedExp(_, {pos: _, def: Symbol(name)}):
                name;
            default:
                throw CompileError.fromExp(nameExp, 'The first argument to $formName should be a variable name or typed variable name.');
        };
    }

    static function varOrProperty(formName:String, wholeExp:ReaderExp, args:Array<ReaderExp>, convert:ExprConversion):Field {
        wholeExp.checkNumArgs(2, 3, '($formName [optional :type] [variable] [optional: &mut] [value])');

        var name = fieldName(formName, args[0]);
        var access = fieldAccess(formName, name);

        var valueIndex = 1;
        switch (args[1].def) {
            case MetaExp("mut"):
                valueIndex += 1;
            default:
                access.push(AFinal);
        }

        return {
            name: name,
            access: access,
            kind: FVar(switch (args[0].def) {
                case TypedExp(type, _):
                    Helpers.parseComplexType(type, args[0]);
                default: null;
            }, convert(args[valueIndex])),
            pos: Context.currentPos()
        };
    }

    static function funcOrMethod(formName:String, wholeExp:ReaderExp, args:Array<ReaderExp>, convert:ExprConversion):Field {
        wholeExp.checkNumArgs(3, null, '($formName [optional :type] [name] [[argNames...]] [body...])');

        var name = fieldName(formName, args[0]);
        var access = fieldAccess(formName, name);

        return {
            name: name,
            access: access,
            kind: FFun(Helpers.makeFunction(args[0], args[1], args.slice(2), convert)),
            pos: Context.currentPos()
        };
    }
}
