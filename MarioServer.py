#### EDITABLE PARAMETERS (you can change these)

# The port that this python server will run on.
PORT = 2022



#### LIBRARY IMPORTS
import os, math, socket



#### CONSTANT VARIABLES

# The maximum ammount of data that the client might send at once.
BUFFER_SIZE = 512



#### UTILITY FUNCTIONS

# A debugging function that will log the current input vector as an NxN matrix.
def logInputs(input):
    # Clear the console so that we don't overflow it.
    os.system('cls')

    # Split the input into an array.
    inputs = input.split()

    # Validate the input.
    if inputs[-1] != "END":
        print("[WARNING]: Invalid input recieved from server")
        return

    # Get the "vision size".
    visionSize = math.floor((math.sqrt(len(inputs)-1) - 1) / 2)

    # Print the network inputs as a matrix.
    for y in range(0,visionSize*2+1):
        line = ""
        for x in range(0,visionSize*2+1):
            if x==visionSize and y==visionSize:
                # Replace the center position with a '*'.
                line = line + " * "
            else:
                # Print the input value.
                line = line + "{:2s}".format(inputs[y*(visionSize*2 + 1) + x]) + " "
        
        # Log a single row at a time.
        print(line)



#### CREATE PYTHON SERVER

# Create and bind the socket.
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.bind(('127.0.0.1', PORT))
sock.listen(1)
print(f"[NOTICE]: Server Started on 127.0.0.1:{PORT}")

# Wait for a client to connect.
connection, clientAddress = sock.accept()

# Ensure valid connection.
frameCounter = 0
with connection:
    print(f"[NOTICE]: Connection made by {clientAddress[0]}:{clientAddress[1]}")

    # The main loop. Wait for a network, process it, and send back inputs.
    while True:
        # Wait for an incoming message.
        data = connection.recv(BUFFER_SIZE).decode()
        if not data:
            print("[NOTICE]: Connection closed by client")
            break
        
        # TODO: Remove.
        # Print every Xth message as a matrix.
        frameCounter += 1
        if(frameCounter % 60 == 0):
            logInputs(data)
        
        # After processing the message, send back a response.
        connection.sendall(b"END\n")
