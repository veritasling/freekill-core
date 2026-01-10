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

  // 以下都在Lobby.qml加载
  property var client // ClientInstance
  property var selfPlayer // Self
  property var fk // 即Lua里面的Fk

  // Backend已提供的C++方法，简单封装
  function call(funcName, ...params) {
    return backend.callLuaFunction(funcName, [...params]);
  }

  function ev(lua) {
    return backend.evalLuaExp(`return ${lua}`);
  }

  function tr(src) {
    return backend.translate(src);
  }

  // 将func（一个Lua函数字符串）包装成js函数。
  // js函数在调用时，会将参数表都翻译成Lua代码的形式，
  // 最后拼出一个Lua函数调用的式子并ev
  function fn(func) {
    return (...params) => ev(`(${func})(${
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

  function createProxy(exp) {
    return new Proxy({
      toString: () => ev(`tostring(${exp})`),
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

          if type(v) == "table" then
            if v.class then
              return { "class", v }
            elseif v[1] and type(v[1]) == "table" and v[1].class then
              return { "classArray", v }
            end
          end
          return { tp, v }
        end`)(prop);
        if (tp === "function") {
          return fn(`function(...) return ${exp}:${prop}(...) end`);
        } else if (tp === "class") {
          return createProxyFromCbor(v);
        } else if (tp === "classArray") {
          return v.map(createProxyFromCbor);
        } else {
          return v;
        }
      }
    });
  }

  function createProxyFromCbor(v) {
    const u8 = new Uint8Array(v);
    let binStr = "";
    for (const u of u8) {
      binStr += "\\x" + u.toString(16).padStart(2, "0");
    }
    return createProxy(`cbor.decode('${binStr}')`);
  }

  // 求值一个Lua中的exp
  // - 若为基本类型，直接返回相关值
  // - 若为userdata或协程，则无法求出，返回null
  // - 若为function，用Lua.fn包裹
  // - 若为表：
  //   - 若为能被JSON编码的简单表，基于JSON返回对应的Js值
  //   - 类实例或数组，返回Proxy或数组
  //
  // Proxy可以像Lua对象那样读取属性、调用方法，但有这些限制：
  // - 不能返回不为方法的function，所有function视为方法
  // - 其他情况下，如果返回值不能被cbor编码，则会为null
  function evaluate(exp) {
    const luaType = ev(`type(${exp})`);
    if (luaType === "userdata" || luaType === "thread") {
      return null;
    }
    if (luaType === "function") {
      return fn(exp);
    }
    if (luaType !== "table") return ev(exp);

    const isClass = ev(`not not ${exp}.class`);
    const isClassArr = ev(`not not (${exp}[1] and ${exp}[1].class)`);
    if (!isClass && !isClassArr) return ev(exp);
    
    if (isClass) {
      return createProxy(exp);
    }
    if (isClassArr) {
      return ev(exp).map(createProxyFromCbor);
    }
  }
}
