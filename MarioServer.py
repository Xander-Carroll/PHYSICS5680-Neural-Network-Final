#### EDITABLE PARAMETERS (you can change these)

# The port that this python server will run on.
PORT = 2022

# The number of hidden layers and neurons in those layers of the network.
HIDDEN_LAYERS = 2
HIDDEN_NODES = 128

# How heavily weighted each part of the reward function is.
W_DISTANCE = 10
W_TIME = 0.1
W_WIN = 2000.0

# How much long term reward matters (near 1 to prioritize long-term gain).
GAMMA = 0.95 

# The percentage of the time that a random action will be taken (0 to use only the trained network).
EPSILON = 0.01

# The q-value we have to meet to actually take an action.
ACTION_THRESHOLD = 0.5



#### LIBRARY IMPORTS

# Standard library imports
import os, math, socket

# External library imports
import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, Model, optimizers



#### CONSTANT VARIABLES

# The maximum ammount of data that the client might send at once.
BUFFER_SIZE = 512

# The maximum ammount of time between packouts without aborting (seconds).
SOCKET_TIMEOUT_LENGTH = 4.0

# The buttons that the agent can learn to press.
BUTTON_LIST = ["UP", "DOWN", "LEFT", "RIGHT", "A", "B"]

# The width of the longest level (pixels) and time limit of the longest level (frames).
MAX_LEVEL_WIDTH = 6656
MAX_LEVEL_TIME = 9600



#### SCRIPT VARIABLES

# The current Q-Network
qNetwork = None

# The "vision-size" that is being used. Is determined by the length of the sent matrix.
visionSize = None

# The current frame
currentFrame = 0

# Previous network information
prevState = None
prevActions = None

# Optimizer function
opt = optimizers.Adam(1e-4)



#### UTILITY FUNCTIONS

# The reward based on these parameters.
def currentReward(playerWin, playerX, currentFrame):
    reward = 0

    reward += (playerX / MAX_LEVEL_WIDTH) * W_DISTANCE
    reward -= (currentFrame / MAX_LEVEL_TIME) * W_TIME
    if playerWin: reward += W_WIN

    return reward

# Creates and returns the Q-network model using TensorFlow.
def initNetwork(inputSize):
    # Determine the vision size from the length of the input message.
    global visionSize
    visionSize = math.floor((math.sqrt(inputSize-2) - 1) / 2)

    # Determine the shape of the network from the vision-size.
    stateShape = (visionSize*2+1,visionSize*2+1,1)

    # Add the input layer.
    x = layers.Input(stateShape)
    y = layers.Flatten()(x)

    # Add the hidden layers.
    for _ in range(HIDDEN_LAYERS):
        y = layers.Dense(HIDDEN_NODES, activation='relu')(y)
    
    # Add the output layer.
    out = layers.Dense(len(BUTTON_LIST))(y)

    # Return the model.
    return Model(x, out)

# Updates the Q-network model using TensorFlow.
def updateNetwork(prevState, prevActions, reward, currentState):
    global opt, qNetwork

    with tf.GradientTape() as tape:
        q = qNetwork(prevState[np.newaxis,...])[0]
        qNext = qNetwork(currentState[np.newaxis,...])[0]
        target = tf.where(prevActions, reward + GAMMA * qNext, q)
        loss = tf.reduce_mean((target - q)**2)
        
    grads = tape.gradient(loss, qNetwork.trainable_variables)
    opt.apply_gradients(zip(grads, qNetwork.trainable_variables))

# Given the state of the game, determines the best actions (buttons) to press. Called each frame.
def processFrame(data):
    global qNetwork, currentFrame, prevState, prevActions
    currentFrame += 1

    # Split the data into an array.
    inputs = data.split()

    # Validate the input.
    if inputs[-1] != "END":
        print("[WARNING]: Invalid input recieved from server.")
        return

    # Ensure that the network exists.
    if qNetwork == None:
        qNetwork = initNetwork(len(inputs))

    # Extract player data from the input message.
    playerWin = int(inputs[0]) == 1
    playerX = int(inputs[1])

    # Extract level data from the input message.
    tileMap = np.array(inputs[2:-1], dtype='int8')
    state = tileMap.reshape((visionSize*2+1,visionSize*2+1,1))

    # Take the action dictated by the network.
    qVals = qNetwork(state[np.newaxis,...])[0].numpy()
    actions = [i for i, q in enumerate(qVals) if q > ACTION_THRESHOLD]

    # Per-button greedy exploration. Take a random action.
    actions = [i if np.random.rand() > EPSILON else np.random.randint(2) for i in range(len(BUTTON_LIST))]

    # Update the network.
    if prevState is not None:
        reward = currentReward(playerWin, playerX, currentFrame)
        prevActionsBool = np.zeros(len(BUTTON_LIST), dtype=bool)
        prevActionsBool[prevActions] = True
        updateNetwork(prevState, prevActionsBool, reward, state)
    
    # Save for the next frame.
    prevState = state
    prevActions = actions

    # Return the buttons that should be pressed this frame.
    return [BUTTON_LIST[i] for i in actions]



#### CREATE PYTHON SERVER

def main():
    global currentFrame

    # Create and bind the socket.
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.bind(('127.0.0.1', PORT))
    sock.listen(1)
    print(f"[NOTICE]: Server Started on 127.0.0.1:{PORT}")

    # Wait for a client to connect.
    connection, clientAddress = sock.accept()

    # Ensure valid connection.
    with connection:
        print(f"[NOTICE]: Connection made by {clientAddress[0]}:{clientAddress[1]}")

        # After making the initial connection, set a time limit on the connection.
        connection.settimeout(SOCKET_TIMEOUT_LENGTH) 

        # The main loop. Wait for a network, process it, and send back inputs.
        while True:
            try:
                # Wait for an incoming message.
                data = connection.recv(BUFFER_SIZE).decode()
                if not data:
                    print("[NOTICE]: Connection closed by client.")
                    break

                # Process the sent data and decide what buttons to press.
                actionList = processFrame(data)
                actionString = " ".join(actionList)
                
                # Send back a response.
                if currentFrame%60==0: print(actionString)
                connection.sendall(b"END\n")

            except socket.timeout:
                print("[NOTICE]: Connection timeout. Closing connection.")
                break
            except socket.error as e:
                print(f"[ERROR]: Socket Error: {e}")
                break
            
        connection.close()
        sock.close()

if __name__ == "__main__":
    main()