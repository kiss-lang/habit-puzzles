package kiss;

import haxe.macro.Expr;
import haxe.macro.Context;
import kiss.Reader;
import kiss.Types;

using StringTools;

// Field forms convert Kiss reader expressions into Haxe macro class fields
typedef FieldFormFunction = (position:String, args:Array<ReaderExp>, convert:ExprConversion) -> Field;

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

    static function fieldName(formName:String, position:String, nameExp:ReaderExp) {
        return switch (nameExp) {
            case Symbol(name):
                name;
            default:
                throw 'The first argument to $formName at $position should be a variable name';
        };
    }

    static function varOrProperty(formName:String, position:String, args:Array<ReaderExp>, convert:ExprConversion):Field {
        if (args.length != 2) {
            throw '$formName with $args at $position is not a valid field definition';
        }

        var name = fieldName(formName, position, args[0]);
        var access = fieldAccess(formName, name);

        return {
            name: name,
            access: access,
            kind: FVar(null, // TODO allow type anotations
                convert(args[1])),
            pos: Context.currentPos()
        };
    }

    static function funcOrMethod(formName:String, position:String, args:Array<ReaderExp>, convert:ExprConversion):Field {
        if (args.length <= 2) {
            throw '$formName with $args is not a valid function/method definition';
        }

        var name = fieldName(formName, position, args[0]);
        var access = fieldAccess(formName, name);

        return {
            name: name,
            access: access,
            kind: FFun({
                args: switch (args[1]) {
                    case ListExp(funcArgs):
                        [
                            for (funcArg in funcArgs)
                                {
                                    name: switch (funcArg) {
                                        case Symbol(name):
                                            name;
                                        default:
                                            throw '$funcArg should be a symbol for a function argument';
                                    },
                                    type: null
                                }
                        ];
                    default:
                        throw '$args[1] should be an argument list';
                },
                ret: null,
                expr: {
                    pos: Context.currentPos(),
                    expr: EReturn(convert(CallExp(Symbol("begin"), args.slice(2))))
                }
            }),
            pos: Context.currentPos()
        };
    }
}
