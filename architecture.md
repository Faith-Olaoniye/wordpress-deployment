# Architecture Document
## WordPress + MySQL Deployment on AWS

## 1. How the Components Connect
User's Browser
      |
      | HTTP request (port 80)
      ▼
EC2 Instance (Ubuntu server on AWS)
      |
      | Docker routes the request
      ▼
WordPress Container (port 80)
      |
      | Database queries over private Docker network
      ▼
MySQL Container
      |
      | Writes data to mounted folder
      ▼
EBS Volume (/mnt/mysql-data)
      |
      | backup.sh runs mysqldump + aws s3 cp
      ▼
S3 Bucket (timestamped .sql files)

The user never talks to MySQL directly. WordPress sits in the middle. It receives requests from the browser and fetches data from MySQL. MySQL is completely hidden from the internet.


## 2. Why EBS Instead of Storing Data Inside the Container?

Docker containers are temporary by design. When a container stops, restarts, or is replaced with a newer version, everything stored inside it is wiped. This is fine for the application code (we can always re-download the WordPress image), but it is a serious problem for a database.

Without EBS, every time the MySQL container restarted we would lose all WordPress posts, user accounts, settings, and media. The site would reset to a blank installation every single time.

EBS is an external hard drive that exists independently of the container. By mapping /mnt/mysql-data (on the server) to /var/lib/mysql (inside the container), MySQL thinks it is writing to its normal location but the data is actually going to the EBS volume. The container can be deleted and recreated 
and the data is completely unaffected.


## 3. Security Group Configuration

Two inbound ports were opened:

**Port 22 (SSH)** :It is required to connect to the server from a terminal to upload files, run scripts, and manage the instance. Without this, there is no way to access the server remotely.

**Port 80 (HTTP)**: It is required for users to visit the WordPress site in their browser. WordPress listens on port 80 inside its container, and this port maps it to the outside world.

**Known security risk:** Port 22 is currently open to all IP addresses (0.0.0.0/0). This means anyone on the internet can attempt to log in via SSH. For this assignment this is acceptable because we are using a key pair (not a password), which is very difficult to brute-force. In a production environment the right approach would be to restrict port 22 to only your specific IP address, or use AWS Systems Manager Session Manager to remove the need for port 22 entirely.

---

## 4. What Happens if the EC2 Instance Crashes?

**What survives:**
- All WordPress content — posts, pages, users, settings. This data is on the EBS volume which is independent of the EC2 instance.
- All database backups in S3. S3 is completely separate from EC2 and is unaffected by anything that happens to the server.

**What is lost:**
- The running application. WordPress and MySQL containers stop when the server goes down. Someone visiting the site would see an error until the server is restored.
- The .env file stored on the server. This would need to be recreated when setting up a new instance.
- Any backup that was mid-upload at the moment of the crash.

**Recovery path:** Launch a new EC2 instance, re-attach the same EBS volume, re-upload the .env file, run provision.sh, and start the containers with docker compose up -d. The site would be back online with all data intact.

---

## 5. Scaling to 100x More Users

I do not have deep experience with scaling yet, but thinking it through:

The current setup has a single point of failure — one server doing everything. With 100x more users this would quickly become overwhelmed.

Some changes I think would help:

- **Multiple EC2 instances** running WordPress behind a load balancer, so traffic is spread across several servers instead of one. AWS offers a service called Elastic Load Balancing for this.

- **A managed database service** like AWS RDS instead of running MySQL ourselves in a container. RDS handles backups, failover, and scaling automatically and is more reliable than a self-managed container.

- **A CDN (Content Delivery Network)** like AWS CloudFront to serve images and static files from locations closer to the user, reducing load on the server.

- **Auto Scaling** so AWS automatically adds more servers during peak traffic and removes them when traffic drops, keeping costs under control.

The database would likely become the bottleneck first since both WordPress instances would be trying to read and write to the same MySQL server at the same time.