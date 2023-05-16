# Arduino-Automated-Jail-Door-Control

## Introduction to the Problem and Solution

The traditional way of jail door handling is often lacking in terms of automation, security, and efficiency which are crucial for creating an ideal environment for prisoners and prison staffs. Operation of jail doors by human labor is vulnerable to errors and requires more effort and time than actually needed. Realizing the problem, we decided to dedicate our project to solve said problem by implementing an Arduino-centric design whcih includes master-slave configurations, buttons, an LCD with serial communication protocols, motors, and others. The objective is to maximize security and efficiency while providing some information about the status of the jail doors in real-time.

Automation with Arduino is meant as a solution to the challenges introduced by the old mechanism of jail door handling. The challenges are eliminating delays and inefficiencies that may affect the workflow inside the prison, increasing monitoring and security capabilities bys showing jail doors' status in real-time, and also maintaining the health and safety of prisoners and staffs.

The old door handling mechanism is full of limitations. By developing this solution, our aim is to increase productivity, security, and efficiency for prison-related operations.

### Solution

The Arduino is responsible for automating tasks and mechanisms for jail door operations. Each jail door has a button connected to the microcontroller to control the opened-or-closed status. A special button to trigger a collective action towards all doors is also implemented for ease of use to the operator and can be scaled for future implementations, such as detecting abnormal conditions.

To show real-time updates of the jail doors' status, we utilize light-emitting diodes (LEDs) as a visual indicator to each door. When a door is opened, the LED representing the door turns on and when it is closed, it turns off. This increases the monitoring capabilities and awareness of staffs and guards.

To simulate an automatic open-close mechanism for the doors, motors are implemented to avoid any manual configuration. The doors are also connected to a light sensor circuit called light-dependent resistor (LDR) and a temperature sensor circuit (DHT11). The LDR detects night and day light where doors automatically close when there is little light (night) and open when there is enough light (day). The DHT11 sensor scans for an overheat that implies fire inside the prison, in which case all doors automatically open.

## Hardware Design and Implementation Details

#### Proteus Design
![Proteus Design](https://github.com/Jordinia/Arduino-Automated-Jail-Door-Control/blob/main/assets/finalproteus.jpg?raw=true)
#### Hardware Design
![Proteus Design](https://github.com/Jordinia/Arduino-Automated-Jail-Door-Control/blob/main/assets/finalhardware.jpg?raw=true)

## Test Results and Performance Evaluation

###  Features

#### Open/Close of Individual Doors
![Hopenclose](https://github.com/Jordinia/Arduino-Automated-Jail-Door-Control/blob/main/assets/openclosedoorproteus.gif?raw=true)
![High temperature auto open](https://github.com/Jordinia/Arduino-Automated-Jail-Door-Control/blob/main/assets/openclosedoor.gif?raw=true)

#### Emergency Close Door
![Hopenclose](https://github.com/Jordinia/Arduino-Automated-Jail-Door-Control/blob/main/assets/emergencyclose.gif?raw=true)

#### Low Light Auto Close
![Hopenclose](https://github.com/Jordinia/Arduino-Automated-Jail-Door-Control/blob/main/assets/lowlightautoclose.gif?raw=true)

#### High Temperature Auto Open
![High temperature auto open](https://github.com/Jordinia/Arduino-Automated-Jail-Door-Control/blob/main/assets/hightempautoopen.gif?raw=true)
