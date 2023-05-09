import ballerina/io;
import ballerina/websocket;

map<int> userMap = {};
map<websocket:Caller> connectionMap = {};
isolated int lastUserId = 0;

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
        int currentUserId;

        lock {
            lastUserId += 1;
            currentUserId = lastUserId;
        }

        userMap[caller.getConnectionId()] = currentUserId;
        connectionMap[caller.getConnectionId()] = caller;

        foreach string connectionId in connectionMap.keys() {
            websocket:Caller connectedCaller = connectionMap.get(connectionId);
            json broadCastMessage = { "type": "users", "count": userMap.length(),  "new_user": true, "id": currentUserId };
            check connectedCaller->writeMessage(broadCastMessage);
        }
    }

    remote function onClose(websocket:Caller caller) returns error? {
        _ = connectionMap.remove(caller.getConnectionId());
        int userId = userMap.remove(caller.getConnectionId());

        foreach string connectionId in connectionMap.keys() {
            websocket:Caller connectedCaller = connectionMap.get(connectionId);
            json broadCastMessage = { "type": "users", "count": userMap.length(),  "new_user": false, "id": userId };
            check connectedCaller->writeMessage(broadCastMessage);
        }

        if userMap.length() == 0 {
            lock {
                lastUserId = 0;
            }
        }
    }

    remote function onMessage(websocket:Caller caller, string chatMessage) returns error? {
        io:println("Client Message - ", chatMessage);

        json event = check chatMessage.fromJsonString();
        string message = check event.message;

        if event.action == "message" {
            foreach string connectionId in connectionMap.keys() {
                websocket:Caller connectedCaller = connectionMap.get(connectionId);
                json broadCastMessage = { "type": "msg", "msg": message,  "id": userMap[caller.getConnectionId()] };
                check connectedCaller->writeMessage(broadCastMessage);
            }
        } else {
            io:println("Unsupported event type - ", event.name);
        }
    }
}
