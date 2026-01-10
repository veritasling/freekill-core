// SPDX-License-Identifier: GPL-3.0-or-later

pragma Singleton
import QtQuick

QtObject {
  // mock
  readonly property var backend: typeof Backend !== 'undefined' ? Backend : {
    callLuaFunction: (fn, params) => {
      console.log(`Lua.call: ${fn} ${params}`);
    },
    evalLuaExp: (exp) => {
      console.log(`Lua.evaluate: ${exp}`);
    },
    translate: (src) => {
      return src;
    },
  };

  // Backend已提供的C++方法，简单封装
  function call(funcName, ...params) {
    return backend.callLuaFunction(funcName, [...params]);
  }

  function _eval(lua) {
    return backend.evalLuaExp(`return ${lua}`);
  }

  function tr(src) {
    return backend.translate(src);
  }

  // 将func（一个Lua函数字符串）包装成js函数。
  // js函数在调用时，会将参数表都翻译成Lua代码的形式，
  // 最后拼出一个Lua函数调用的式子并_eval
  function fn(func) {
    return (...params) => _eval(`(${func})(${
      [...params].map(v => {
        if (["string", "number", "boolean"].includes(typeof v)) return JSON.stringify(v);
        if (typeof v === "object") {
          if (v === null) return "nil";
          if (v._L) return v._L;
          return `json.decode '${JSON.stringify(v)}'`;
        }
        return "nil"
      }).join(',')
    })`);
  }

  // 求值一个Lua中的exp
  // - 若为基本类型，直接返回相关值
  // - 若为函数或userdata或协程，则无法求出，返回null
  // - 若为表：
  //   - 若为能被JSON编码的简单表，基于JSON返回对应的Js值
  //   - 其他情况返回Proxy
  //
  // Proxy可以像Lua对象那样读取属性、调用方法，但如果返回值不能被cbor编码，则会为null
  function evaluate(exp) {
    const luaType = _eval(`type(${exp})`);
    if (luaType === "function" || luaType === "userdata" || luaType === "thread") {
      return null;
    }
    if (luaType !== "table") return _eval(exp);

    const isClass = _eval(`not not ${exp}.class`);
    if (!isClass) return _eval(exp);
    return new Proxy({
      toString: () => _eval(`tostring(${exp})`),
      _L: exp,
    }, {
      get(target, prop) {
        if (target[prop]) return target[prop];

        const [tp, v] = fn(`function(prop)
          local v = ${exp}[prop]
          local tp = type(v)

          if tp == "function" or tp == "userdata" or tp == "thread" then
            return { tp, nil }
          end

          if type(v) == "table" and v.class then
            -- 这里返回v的话，会在QML中作为ArrayBuffer
            return { "class", v.__tocbor and v or nil }
          end
          return { tp, v }
        end`)(prop);
        if (tp === "function") {
          return fn(`function(...) return ${exp}:${prop}(...) end`);
        } else if (tp === "class") {
          if (v instanceof ArrayBuffer) {
            const u8 = new Uint8Array(v);
            let binStr = "";
            for (const u of u8) {
              binStr += "\\x" + u.toString(16).padStart(2, "0");
            }
            return evaluate(`cbor.decode('${binStr}')`);
          }
        } else {
          return v;
        }
      }
    });
  }
}
