/* ************************************************************************

   Copyrigtht: OETIKER+PARTNER AG
   License:    Proprietary
   Authors:    Tobias Oetiker, Fritz Zaucker

   $Id: Rpc.js 136 2010-06-15 21:57:02Z oetiker $

************************************************************************ */

/**
 * The Rpc class inherits from {@link qx.io.remote.Rpc}. It knows a bunch about
 * the way we like Rpc to happen in Agrammon conntext.
 *
 * Derived from Tobi's Nequal Rpc.js
 */
qx.Class.define('agrammon.io.remote.Rpc', {
    extend : qx.io.remote.Rpc,
    type : 'singleton',

    /**
     * Create an instance of Rpc.
     */
    construct : function() {
        this.base(arguments);

        this.set({
            timeout     : 25 * 1000,
            url         : 'jsonrpc/',
            serviceName : 'Agrammon'
        });

    },

    members : {

        __baseUrl:  '',

        // FIX ME: why is this needed anywhere?
        getBaseUrl : function() {
            return this.__baseUrl;
        },

        // Fix me: use Tobi's  asyncCall handler
        /**
         * A asyncCall handler which tries to
         * login in the case of a permission exception.
         *
         * @param handler {Function} the callback function.
         * @param methodName {String} the name of the method to call.
         * @return {var} the method call reference.
         */
        callAsyncOld : function(handler, methodName) {
            var origArguments = arguments;
            var origThis = this;
            var origHandler = handler;

            var superHandler = function(ret, exc, id) {
                if (exc && exc.code == 6) {
                    var login = agrammon.module.user.Login.getInstance();
                    login.addListenerOnce('login', function(e) {
                        origArguments.callee.base.apply(origThis, origArguments);
                    });
                    login.open();
                    return;
                }

                origHandler(ret, exc, id);
            };

            if (methodName != 'login') {
                arguments[0] = superHandler;
            }

            arguments.callee.base.apply(this, arguments);
        },


        callAsync : function(handler, methodName, data) {
            var req = new qx.io.request.Xhr(methodName, "POST");
            if (data != null) {
                req.setRequestData(data);
                req.setRequestHeader("Content-Type", "application/json");
            }
            req.addListener("statusError", function(e) {
                var req = e.getTarget();
                var response = req.getResponse();
                var status = req.getStatus();
                var statusText = req.getStatusText();
                console.error('callAsync('+methodName+'): statusError, response=', response, ', status=', status, ':', statusText);
                if (response && response.error) {
                    handler(response.error, status);
                }
                else {
                    let msg = 'method=' + methodName + ', status=' + status + ': ' + statusText;
                    alert(msg);
                }
            }, this);
            req.addListener("success", function(e) {
                var req = e.getTarget();
                var response = req.getResponse();
                var status = req.getStatus();
                var statusText = req.getStatusText();
                console.log('callAsync(): success, response=', response, ', status=', status, ':', statusText);
                handler(response);
            }, this);
            req.send();
        },



        /* A variant of the asyncCall method which pops up error messages
         * generated by the server automatically.
         *
         * Note that the handler method only gets a return value never an exception
         * It just does not get called when there is an exception.
         *
         * @param handler {Function} the callback function.
         * @param methodName {String} the name of the method to call.
         * @return {var} the method call reference.
         */
        callAsyncSmart : function(handler, methodName) {
            var origHandler = handler;

            var superHandler = function(ret, exc, id) {
                if (exc) {
                    agrammon.ui.dialog.MsgBox.getInstance().exc(exc);
                } else {
                    origHandler(ret);
                }
            };
            arguments[0] = superHandler;
            this.callAsync.apply(this, arguments);
        }
    }
});
