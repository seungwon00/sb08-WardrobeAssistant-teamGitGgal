# ===== Build Stage =====
FROM amazoncorretto:17 AS builder
WORKDIR /app

# Gradle wrapper 및 설정 파일 복사 (의존성 캐싱)
COPY gradlew .
COPY gradle gradle
COPY build.gradle settings.gradle ./

# gradlew 실행에 필요한 xargs 등 제공 (amazoncorretto 베이스엔 findutils 미포함)
RUN yum install -y findutils && yum clean all

# 의존성 다운로드 (캐싱 레이어)
RUN chmod +x ./gradlew && \
    ./gradlew dependencies --no-daemon

# 전체 소스 복사 후 빌드
COPY . .
RUN ./gradlew clean build -x test --no-daemon


# ===== Runtime Stage =====
FROM amazoncorretto:17-alpine
WORKDIR /app

# 비루트 사용자 생성
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

# 빌드된 JAR 복사
COPY --from=builder /app/build/libs/*.jar app.jar

# 권한 설정
RUN chown -R appuser:appuser /app
USER appuser

# 애플리케이션 포트
EXPOSE 8080

# JVM 및 환경 변수
ENV JAVA_OPTS="-XX:+UseG1GC -XX:MaxRAMPercentage=60.0 -XX:InitialRAMPercentage=20.0 -XX:+ExitOnOutOfMemoryError"
ENV TZ=Asia/Seoul
ENV SPRING_PROFILES_ACTIVE=prod

# 헬스체크
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget -q -O- http://localhost:8080/actuator/health || exit 1

# 컨테이너 실행
ENTRYPOINT ["sh", "-c", "exec java ${JAVA_OPTS} -Duser.timezone=${TZ} -Dspring.profiles.active=${SPRING_PROFILES_ACTIVE} -jar app.jar"]