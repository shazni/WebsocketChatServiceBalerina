import ballerina/io;
import ballerina/websocket;

map<int> USER_MAP = {};
map<websocket:Caller> CONNECTION_MAP = {};
int USER_ID = 0;

service / on new websocket:Listener(9876) {
    resource function get .() returns websocket:Service {
        return new ChatService();
    }
}

service class ChatService {
    *websocket:Service;

    public isolated function init() {
        io:println("init() called for a new connection");
    }

    remote function onOpen(websocket:Caller caller) returns error? {
        io:println("Connection is opened for a new client");
        USER_ID = USER_ID + 1;
        USER_MAP[caller.getConnectionId()] = USER_ID;
        CONNECTION_MAP[caller.getConnectionId()] = caller;

        foreach string connectionId in CONNECTION_MAP.keys() {
            websocket:Caller connectedCaller = CONNECTION_MAP.get(connectionId);
            json broadCastMessage = { "type": "users", "count": USER_MAP.length(),  "new_user": true, "id": USER_ID };
            check connectedCaller->writeMessage(broadCastMessage.toJsonString());
        }
    }

    remote function onClose(websocket:Caller caller) returns error? {
        _ = CONNECTION_MAP.remove(caller.getConnectionId());
        int userId = USER_MAP.remove(caller.getConnectionId());

        foreach string connectionId in CONNECTION_MAP.keys() {
            websocket:Caller connectedCaller = CONNECTION_MAP.get(connectionId);
            json broadCastMessage = { "type": "users", "count": USER_MAP.length(),  "new_user": false, "id": userId };
            check connectedCaller->writeMessage(broadCastMessage.toJsonString());
        }

        if USER_MAP.length() == 0 {
            USER_ID = 0;
        }
    }

    remote function onMessage(websocket:Caller caller, string chatMessage) returns error? {
        io:println("Client Message - ", chatMessage);

        json event = check chatMessage.fromJsonString();
        string message = check event.message;

        if event.action == "message" {
            foreach string connectionId in CONNECTION_MAP.keys() {
                websocket:Caller connectedCaller = CONNECTION_MAP.get(connectionId);
                json broadCastMessage = { "type": "msg", "msg": message,  "id": USER_MAP[caller.getConnectionId()] };
                check connectedCaller->writeMessage(broadCastMessage.toJsonString());
            }
        } else {
            io:println("Unsupported event type - ", event.name);
        }
    }
}
