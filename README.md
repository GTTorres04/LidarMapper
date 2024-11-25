# LidarMapper

## Author  
**Gonçalo Torres**

---

## Version  
**1.0.0**  

---

## Description
This Project aims to utilize various iPhone sensors (LiDAR, accelerometer, gyroscope, magnetometer, camera, GPS, etc.) to map a space. The information will be transmitted in the form of ROS messages via WebSockets to a PC, where 3D reconstruction of the space will be performed using point clouds.

Key features include:
- Integration of multiple iPhone sensors for data collection.  
- Data transmission over WebSockets.  
- Processing of point clouds for 3D reconstruction.

---

## Prerequisites 

### iPhone Application
- **iOS Version**: 17.2 or later.  
- **Xcode**: Version 14.0 or later.
- **Swift Language Version**: Version 5 or later. 

### PC Requirements
- **Operating System**: macOS.
- **macOS Version**: macOS Ventura (version 13) or later.
- **Docker**: Ensure you have Docker installed for containerized execution.
- **Foxglove Studio** (Optional for visualization):
  - Use it to visualize sensor data streams in real-time.   

### iPhone Requirements
- iPhone 12 Pro or later

---

## Adicional Notes:
Make sure to change the ip adress in order to work correctly. Use ws://(IP ADRESS):9090  

---

## License

 [LidarMapper](https://github.com/GTTorres04/LidarMapper) © 2024 by [Gonçalo Torres](https://www.isr.uc.pt/index.php/people?task=showpeople.show%28%29&idPerson=2306) is licensed under [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International](https://creativecommons.org/licenses/by-nc-sa/4.0/?ref=chooser-v1) 

---




