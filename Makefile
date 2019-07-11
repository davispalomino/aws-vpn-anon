######################
# VARIABLES REQUERIDAS
######################
# REGION: Region de despliegue de infraestructura.
# TYPE:	  El tipo de servidor para la conexión VPN standar/advance/high.
# SUBNET: La Subnet en la que se desplegara la infraestructura (requerida - PUBLIC).
# TFSTATE:Especificar si el tfstate se guardara en s3(bucket), enterprise(terraform) o local (https://www.terraform.io/docs/state/)
#		  local/s3/enterprise si desea usar enterprise debe cambiar la variable ORGANIZATION y agregar el Token
REGION=us-east-1
TYPE=standar
SUBNET=subnet-0e1672288ea096155
TFSTATE=local

######################
# VARIABLES OPCIONALES
######################
# OWNER: 	Nombre del propietario - Name de la instancia.
# PROJECT:	Nombre del proyecto.   - Name de la instancia.
# USER:		Usuario para la conexion VPN.
# PASS: 	Password de la conexion VPN.
OWNER=101ROOT
PROJECT=ACCESS
USER=admin
PASS=demo

##########################
# VARIABLES REMOTE BACKEND
##########################
# https://www.terraform.io/docs/backends/types/remote.html
# En caso de guardar el estado de deploy de la infraestructura en Terraform Enterprise
# https://app.terraform.io
# [Variables para Terraform Enterprise]
ORGANIZATION=101r00tsecurity
PROVIDER=AWS
TOKENTF=000700080009009MYTOKEN
# [Variables para S3 -AWS]
BUCKET=$(shell echo ${OWNER}-${PROJECT}-estado| tr '[:upper:]' '[:lower:]')

###################################
# VARIABLES CONSULTA Y CONSTRUCCION
###################################
# INSTANCE:	El tipo de instancia que se usara para realizar el deploy con Packer.
# https://www.packer.io/
# MI_IP:	Captura la IP Publica Local para luego comparar y validar que la conexion a la VPN 
#			se realizo de manera exitosa.
# SECONDS:	Tiempo para iniciar la conexion, a espera que la isntancia se encuentre RUNNING
#			y con todos los servicios ejecutandose. aws s3 mb s3://${BUUCKET} --region ${REGION} --output text 2>&1
INSTANCE=t2.micro
MI_IP=$(shell curl -s ifconfig.me/ip)
SECONDS=100

quickstart: build validatortf plan deploy vpnaccess
	@echo "The instance was created and the connection to the VPN was successfully"

disconnect: exitvpn destroy
	@echo "All trace was removed"
	@echo "*******THANK U******"

validatortf:
	@if [[ "${TFSTATE}" == "local" ]]; then\
		make localtf ; \
	elif [[ "${TFSTATE}" == "s3" ]]; then\
		make buckettf; \
	elif [[ "${TFSTATE}" == "enterprise" ]]; then\
		make enterprisetf; \
	else \
		echo "*******ERROR LA VARIABLE TFSTATE NO TIENE VALOR*********" ; \
	fi
buckettf:
	@STATUS_BUCKET=$(shell aws s3 ls s3://${BUCKET} --output text 2>&1 | grep -q "not exist"  && echo "nofound"  || echo "found") && \
	if [[ "$${STATUS_BUCKET}" == "nofound" ]]; then\
		echo "*******CREATE REMOTE BACKEND [S3]*******" && \
		aws s3 mb s3://${BUCKET} --region ${REGION} --output text 2>&1 && \
		rm -rf terraform/main.tf && \
		cp -R terraform/main terraform/main.tf && \
		sed -i 's|WORKSPACES|backend "s3"{\nbucket="${BUCKET}"\nkey="terraform.tfstate"\nregion="${REGION}"\n}|g' terraform/main.tf ; \
	else \
		echo "*******SYNC REMOTE TF-STATE [S3]*********" && \
		rm -rf terraform/main.tf && \
		cp -R terraform/main terraform/main.tf && \
		sed -i 's|WORKSPACES|backend "s3"{\nbucket="${BUCKET}"\nkey="terraform.tfstate"\nregion="${REGION}"\n}|g' terraform/main.tf ; \
	fi
	@cd terraform/ && \
	rm -rf spot.info && \
	terraform init \

enterprisetf:
	@echo "*******CREATE REMOTE TF-STATE [Terraform Enterprise]*******" && \
	rm -rf terraform/.terraformrc && \
	cp -R terraform/key terraform/.terraformrc && \
	sed -i 's|TOKENTF|"$(TOKENTF)"|g' terraform/.terraformrc && \
	rm -rf terraform/main.tf && \
	cp -R terraform/main terraform/main.tf && \
	sed -i 's|WORKSPACES|backend "remote"{\nworkspaces {\nname = "$(PROVIDER)-$(OWNER)-$(PROJECT)"\n}\n}|g' terraform/main.tf
	@make enterpriseinit

localtf:
	@echo "*******CREATE LOCAL TF-STATE *******" && \
	rm -rf terraform/main.tf && \
	cp -R terraform/main terraform/main.tf && \
	sed -i 's|WORKSPACES||g' terraform/main.tf
	@cd terraform/ && \
	rm -rf spot.info && \
	terraform init \

build:
	@echo "*******START CONSTRUCTION AMI*******"
	@AMISOURCE=$(shell aws ec2 describe-images --owners 099720109477   --filters Name=root-device-type,Values=ebs Name=architecture,Values=x86_64 Name=name,Values='ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-20170414' Name=ena-support,Values=true --query 'sort_by(Images, &Name)[-1].[ImageId]' --output text --region ${REGION}) && \
	packer build  \
	-var 'Var_region=${REGION}' \
	-var 'Var_subnet_id=${SUBNET}' \
	-var 'Var_instance_type=${INSTANCE}' \
	-var 'Var_source_ami='$${AMISOURCE}'' \
	-var 'Var_project=${PROJECT}' \
	-var 'Var_owner=${OWNER}' \
	-var 'Var_usuario=${USER}' \
	-var 'Var_password=${PASS}' \
	./packer/packer.json
	@echo "*******AMI CREATE*******"

enterpriseinit:
	@export AWS_DEFAULT_REGION="$(REGION)" && \
	export TF_CLI_CONFIG_FILE="$(PWD)/terraform/.terraformrc" && \
	cd terraform/ && \
	rm -rf spot.info && \
	terraform init \
	-backend-config="hostname=app.terraform.io" \
	-backend-config="organization=$(ORGANIZATION)"

plan:
	@echo "*******START DEPLOY INFRASTRUCTURE*******"
	@export AWS_DEFAULT_REGION="$(REGION)" && \
	if [[ "${TFSTATE}" == "enterprise" ]]; then\
		export TF_CLI_CONFIG_FILE="$(PWD)/terraform/.terraformrc" && \
		cd terraform/ && \
		terraform plan \
		-var 'region=${REGION}' \
		-var 'subnet=${SUBNET}' \
		-var 'owner=${OWNER}' \
		-var 'project=${PROJECT}' \
		-var 'type=${TYPE}' ;\
	else \
		cd terraform/ && \
		terraform plan \
		-var 'region=${REGION}' \
		-var 'subnet=${SUBNET}' \
		-var 'owner=${OWNER}' \
		-var 'project=${PROJECT}' \
		-var 'type=${TYPE}' ;\
	fi

deploy:
	@export AWS_DEFAULT_REGION="$(REGION)" && \
	if [[ "${TFSTATE}" == "enterprise" ]]; then\
		export TF_CLI_CONFIG_FILE="$(PWD)/terraform/.terraformrc" && \
		cd terraform/ && \
		terraform apply \
		-var 'region=${REGION}' \
		-var 'subnet=${SUBNET}' \
		-var 'owner=${OWNER}' \
		-var 'project=${PROJECT}' \
		-var 'type=${TYPE}' \
		-auto-approve ;\
	else \
		cd terraform/ && \
		terraform apply \
		-var 'region=${REGION}' \
		-var 'subnet=${SUBNET}' \
		-var 'owner=${OWNER}' \
		-var 'project=${PROJECT}' \
		-var 'type=${TYPE}' \
		-auto-approve ;\
	fi

vpnconect:
	@echo "*******START CONNECTION VPN*******"
	@number=1 ; while [[ $$number -le $(SECONDS) ]] ; do \
	sleep 1s ; \
	echo -ne "$(shell echo "[Loading Instance]") $$number$(shell echo "%")\r"; \
	((number = number + 1)) ; \
	done
	@IPSERVER=$(shell export AWS_DEFAULT_REGION="$(REGION)" && export TF_CLI_CONFIG_FILE="$(PWD)/terraform/.terraformrc" && cd terraform/ && terraform output ipPublic) && \
	sudo yum install -y ppp pptp pptp-setup > /dev/null && \
	echo "Connect to VPN" && \
	echo "Creating configuration file SERVER:$$IPSERVER USER: $(USER) PASS: $(PASS) " && \
	sudo pptpsetup --create config --server $$IPSERVER --username $(USER) --password $(PASS) --encrypt && \
	sudo sed -i 's|--nolaunchpppd| --nobuffer --nolaunchpppd|g' /etc/ppp/peers/config && \
	sudo sh -c "echo -e 'persist\nmru 1400\nlcp-echo-failure 30\nlcp-echo-interval 10' >> /etc/ppp/peers/config" && \
	echo "Register config" && \
	sudo modprobe ppp_mppe && \
	sudo modprobe nf_conntrack_pptp && \
	echo "Establishing Connection" && \
	sudo pppd call config && \
	sudo ifconfig ppp0 mtu 1416 && \
	sleep 3s && \
	echo "Create Conexion" && \
	sudo route add default dev ppp0 && \
	sleep 5s

vpnaccess: vpnconect
ifeq ($(MI_IP), $(shell curl -s ifconfig.me/ip ))
	@echo "Error de Conexion, por favor ejecute: make reconexion"
else
	@sleep 5s
	@echo "*******SUCCESSFUL CONNECTION IP PUBLIC $(shell curl -s ifconfig.me/ip )*******"
endif

tfdestroy:
	@echo "*******DESTROY INFRAESTRUCTURE******"
	@export AWS_DEFAULT_REGION="$(REGION)" && \
	if [[ "${TFSTATE}" == "enterprise" ]]; then\
		export TF_CLI_CONFIG_FILE="$(PWD)/terraform/.terraformrc" && \
		cd terraform/ && \
		terraform destroy \
		-var 'region=${REGION}' \
		-var 'owner=${OWNER}' \
		-var 'project=${PROJECT}' \
		-var 'subnet=${SUBNET}' \
		-var 'type=${TYPE}' \
		-auto-approve && \
		curl \
		--header "Authorization: Bearer ${TOKENTF}" \
		--header "Content-Type: application/vnd.api+json" \
		--request DELETE \
		https://app.terraform.io/api/v2/organizations/seidorperu/workspaces/$(PROVIDER)-$(OWNER)-$(PROJECT) ;\
	else \
		cd terraform/ && \
		terraform destroy \
		-var 'region=${REGION}' \
		-var 'owner=${OWNER}' \
		-var 'project=${PROJECT}' \
		-var 'subnet=${SUBNET}' \
		-var 'type=${TYPE}' \
		-auto-approve ;\
	fi
	@echo "Disconnected from the VPN and the instance was removed"

destroy: tfdestroy
	@echo "*******DELETE AMI******"
	@AMI_ID=$(shell aws ec2 describe-images --filters "Name=name,Values=$(OWNER)-$(PROJECT)-*" --query 'Images[*].ImageId' --region $(REGION) --output text) &&  \
	SNAP_ID=$(shell aws ec2 describe-images --filters "Name=name,Values=$(OWNER)-$(PROJECT)-*" --query 'Images[*].BlockDeviceMappings[*].Ebs.SnapshotId' --region $(REGION) --output text) && \
	aws ec2 deregister-image --image-id $${AMI_ID} --region ${REGION} && \
	aws ec2 delete-snapshot --snapshot-id $${SNAP_ID} --region ${REGION}
	@if [[ "${TFSTATE}" == "s3" ]]; then\
		aws s3 rb s3://${BUCKET} --force  && \
		rm -rf terraform/.terraform && \
		rm -rf terraform/spot.info && \
		rm -rf manifest.json ; \
	else \
		rm -rf terraform/.terraformrc && \
		rm -rf terraform/.terraform && \
		rm -rf terraform/spot.info && \
		rm -rf manifest.json ; \
	fi
exitvpn:
	@echo "*******DISCONNECTING VPN******"
	@sudo ifconfig ppp0 down
	@sudo killall pppd
	@sleep 5s
	@echo "Disconnected from the VPC"
